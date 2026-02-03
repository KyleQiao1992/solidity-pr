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

    /**
     * @dev 拍卖结构体
     */
    struct Auction {
        address seller; // 卖家地址
        address nftContract; // NFT合约地址
        uint256 tokenId; // Token ID
        uint256 startPrice; // 起拍价
        uint256 highestBid; // 当前最高出价
        address highestBidder; // 当前最高出价者
        uint256 endTime; // 拍卖结束时间
        bool active; // 是否激活
    }

    //存储映射： key:listingId作为键
    mapping(uint256 => Listing) public listings; // 挂单映射
    uint256 public listingCounter; // 挂单计数器
    //平台费用设置：
    uint256 public platformFee = 250; // 2.5%
    address public feeRecipient; // 手续费接收地址

    // 拍卖映射
    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;
    //待退款映射 记录每个出价者在每个拍卖中的待退款金额
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;

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

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endTime
    );

    /**
     * @dev 出价事件
     */
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    /**
     * @dev 拍卖结束事件
     */
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice
    );

    /**
     * @dev 构造函数
     * @param _feeRecipient 手续费接收地址
     */
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }

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

        // 获取版税信息
        (address royaltyReceiver, uint256 royaltyAmount) = _getRoyaltyInfo(
            listing.nftContract,
            listing.tokenId,
            listing.price
        );

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
        // 资金分配顺序：版税 -> 平台手续费 -> 卖家收益
        //这个顺序很重要，确保创作者能够优先获得收益
        //如果不支持，版税金额就是0，不影响正常的交易流程
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            (bool successRoyaltyReceiver, ) = royaltyReceiver.call{
                value: royaltyAmount
            }("");
            require(successRoyaltyReceiver, "Royalty transfer failed");
        }

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

    function _getRoyaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) internal view returns (address receiver, uint256 royaltyAmount) {
        if (
            IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)
        ) {
            (receiver, royaltyAmount) = IERC2981(nftContract).royaltyInfo(
                tokenId,
                salePrice
            );
        } else {
            receiver = address(0);
            royaltyAmount = 0;
        }
    }

    /**
     * @dev 创建拍卖
     * @param nftContract NFT合约地址
     * @param tokenId Token ID
     * @param startPrice 起拍价（wei）
     * @param durationHours 拍卖时长（小时）
     * @return auctionId 拍卖ID
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 durationHours
    ) external returns (uint256) {
        require(startPrice > 0, "Start price must be greater than 0");
        require(durationHours >= 1, "Duration must be at least 1 hour");
        require(nftContract != address(0), "Invalid nft contract");

        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nft.getApproved(tokenId) == address(this) ||
                nft.isApprovedForAll(msg.sender, address(this)),
            "NFT is not approved"
        );

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + (durationHours * 1 hours),
            active: true
        });

        emit AuctionCreated(
            auctionCounter,
            msg.sender,
            nftContract,
            tokenId,
            startPrice,
            auctions[auctionCounter].endTime
        );

        return auctionCounter;
    }

    /**
     * @dev 出价
     * @param auctionId 拍卖ID
     * @notice 需要支付足够的ETH，出价必须高于当前最高出价的5%
     */
    function placeBid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];

        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");

        uint256 minBid;
        if (auction.highestBid == 0) {
            minBid = auction.startPrice;
        } else {
            //这个5%的加价规则可以防止恶意小额出价
            minBid = auction.highestBid + (auction.highestBid * 5) / 100; //最低出价是最高出价的5%
        }
        require(msg.value >= minBid, "Bid too low");

        // 如果有之前的出价者，记录他们的待退款金额
        if (auction.highestBidder != address(0)) {
            pendingReturns[auctionId][auction.highestBidder] += auction
                .highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    /**
     * @dev 提取出价退款
     * @param auctionId 拍卖ID
     * @notice 被超越的出价者可以提取他们的资金
     */
    function withdrawBid(uint256 auctionId) external {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No pending return");

        pendingReturns[auctionId][msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev 结束拍卖
     * @param auctionId 拍卖ID
     * @notice 任何人都可以在拍卖结束后调用此函数进行结算
     */
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");

        auction.active = false;

        if (auction.highestBidder != address(0)) {
            // 有人出价，进行结算
            uint256 fee = (auction.highestBid * platformFee) / 10000;

            (address royaltyReceiver, uint256 royaltyAmount) = _getRoyaltyInfo(
                auction.nftContract,
                auction.tokenId,
                auction.highestBid
            );

            uint256 sellerAmount = auction.highestBid - fee - royaltyAmount;

            // 转移NFT
            IERC721(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.highestBidder,
                auction.tokenId
            );

            // 资金分配
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                (bool successRoyalty, ) = royaltyReceiver.call{
                    value: royaltyAmount
                }("");
                require(successRoyalty, "Royalty transfer failed");
            }

            (bool successSeller, ) = auction.seller.call{value: sellerAmount}(
                ""
            );
            require(successSeller, "Transfer to seller failed");

            (bool successFee, ) = feeRecipient.call{value: fee}("");
            require(successFee, "Transfer fee failed");

            emit AuctionEnded(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            // 没有人出价，拍卖流拍
            emit AuctionEnded(auctionId, address(0), 0);
        }
    }
}
