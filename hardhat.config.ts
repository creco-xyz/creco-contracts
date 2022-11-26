import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      chainId: 1337, // allow metamask testing
    },
  },
};

export default config;
