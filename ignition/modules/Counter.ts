import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

//ignition目录是Hardhat 3的新特性，用于Ignition部署系统。这是一个声明式部署系统，支持自动状态管理，适合复杂的系统部署
export default buildModule("CounterModule", (m) => {
  const counter = m.contract("Counter");

  m.call(counter, "incBy", [5n]);

  return { counter };
});
