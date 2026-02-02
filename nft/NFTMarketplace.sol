// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC2981 is IERC165 {
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

/**
 * @title NFTMarketplace
 * @dev 完整的NFT交易市场合约，支持上架、购买、版税和拍卖功能
 * @notice 使用ReentrancyGuard防止重入攻击
 */
contract NFTMarketplace is ReentrancyGuard {
    /**
     * @dev 挂单结构体
     */
    struct Listing {
        address seller; // 存储卖家地址，只有卖家本人可以下架或修改价格
        address nftContract; // NFT合约的地址。因为市场要支持各种NFT，不能写死某个特定合约，所以需要记录是哪个NFT合约
        uint256 tokenId; // 指定是哪个具体的NFT。结合nftContract和tokenId，就能唯一确定一个NFT
        uint256 price; // 售价，以wei为单位
        bool active; // 表示挂单是否有效。当NFT被购买或卖家主动下架时，这个字段会被设为false，防止重复购买
    }

    //存储映射： key:listingId作为键
    mapping(uint256 => Listing) public listings; // 挂单映射
    uint256 public listingCounter; // 挂单计数器
    //平台费用设置：
    uint256 public platformFee = 250; // 2.5%
    address public feeRecipient; // 手续费接收地址

    //event
    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price
    );

    event NFTDelisted(uint256 indexed listingId);

    event PriceUpdated(uint256 indexed listingId, uint256 newPrice);

    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    //上架功能
    //上架是用户在市场出售NFT的第一步。这个功能需要仔细设计，确保安全性和用户体验。
    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external returns (uint256) {
        //价格检查：确保价格大于0。虽然理论上可以设置为0实现赠送，但在实际市场中，0价格可能导致一些问题，所以我们要求价格必须大于0。
        require(price > 0, "Price must be greater than 0");

        //所有权检查：这非常重要。我们调用NFT合约的ownerOf函数，确认调用者确实拥有这个NFT。如果有人试图上架别人的NFT，这里会失败。
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        //所有权检查：这非常重要。我们调用NFT合约的ownerOf函数，确认调用者确实拥有这个NFT。如果有人试图上架别人的NFT，这里会失败。
        require(
            nft.getApproved(tokenId) == address(this) ||
                nft.isApprovedForAll(msg.sender, address(this)),
            "NFT is not approved"
        );

        listingCounter++;
        Listing memory listing = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        listings[listingCounter] = listing;

        emit NFTListed(listingCounter, msg.sender, nftContract, tokenId, price);

        return listingCounter;
    }

    //下架功能实现Sorry
    function delistNFT(uint256 listingId) external {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing is not action");
        require(listing.seller == msg.sender, "Not the seller");

        listing.active = false;

        emit NFTDelisted(listingId);
    }

    //价格更新功能
    function updatePrice(uint256 listingId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than 0");
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing is not action");
        require(listing.seller == msg.sender, "Not the seller");

        listing.price = newPrice;

        emit PriceUpdated(listingId, newPrice);
    }

    function buyNFT(uint256 ListingId) external payable nonReentrant {
        Listing storage listing = listings[ListingId];

        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");

        listing.active = false;

        //平台手续费是售价的2.5%
        uint256 fee = (listing.price * platformFee) / 10000;
        //卖家实际收到的金额是售价减去手续费
        uint256 sellerAmount = listing.price - fee;

        //NFT转移
        //safeTransferFrom 它会检查接收方是否能够处理NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        //资金分配
        //首先将卖家应得的金额转给卖家，然后转平台手续费。所有的转账都使用低级call，并检查返回值，确保转账成功
        (bool successSeller, ) = listing.seller.call{value: sellerAmount}("");
        require(successSeller, "Transfer to seller failed");

        (bool successFeeRecipient, ) = feeRecipient.call{value: fee}("");
        require(successFeeRecipient, "Transfer to fee recipient failed");

        //如果买家支付的金额超过了售价，需要退还多余的ETH
        if (msg.value > listing.price) {
            (bool successBuyer, ) = msg.sender.call{
                value: msg.value - listing.price
            }("");
            require(successBuyer, "Transfer to buyer failed");
        }

        emit NFTSold(ListingId, msg.sender, listing.seller, listing.price);
    }
}
