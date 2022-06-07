import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-abi-exporter";

import "hardhat-deploy";

import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import { NetworkUserConfig } from "hardhat/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });


const DATAHUB_API_KEY = process.env.DATAHUB_API_KEY;
const FUJI_PRIVATE_KEY = process.env.FUJI_PRIVATE_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

const chainIds = {
  goerli: 5,
  hardhat: 1337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
};

// Ensure that we have all the environment variables we need.
const deployerPK = process.env.DEPLOYER_PK ?? "NO_DEPLOYER_PK";
const tokenOwnerPK = process.env.TOKEN_OWNER_PK ?? "NO_TOKEN_OWNER_PK";
// Make sure node is setup on Alchemy website
const alchemyApiKey = process.env.ALCHEMY_API_KEY ?? "NO_ALCHEMY_API_KEY";



function getChainConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const url = `https://eth-${network}.alchemyapi.io/v2/${alchemyApiKey}`;
  return {
      accounts: [deployerPK, tokenOwnerPK],
      chainId: chainIds[network],
      url,
      // gas: 2100000,
      // gasPrice: 8000000000,
  };
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
    networks: {
      localhost: {
        url: "http://127.0.0.1:8545"
      },        
      hardhat: {
          mining: {
            auto: true,
            // interval: 20000 // milliseconds
          },
          chainId: chainIds.hardhat,          
          loggingEnabled: process.env.EVM_LOGGING === "true",
      },
      fuji: {
          url: `https://avalanche--fuji--rpc.datahub.figment.io/apikey/${DATAHUB_API_KEY}/ext/bc/C/rpc`,
          accounts: [deployerPK, tokenOwnerPK],
          gasPrice: 25000000000, //225000000000
                                // 25000000000
          // gas: 10001,
          // chainId: 43113,
        },
      avalanche: {
          url: `https://avalanche--mainnet--rpc.datahub.figment.io/apikey/${DATAHUB_API_KEY}/ext/bc/C/rpc`,
          accounts: [deployerPK, tokenOwnerPK],
          gasPrice: 25000000000,
        },
      // Uncomment for testing. Commented due to CI issues
      mainnet: getChainConfig("mainnet"),
      rinkeby: getChainConfig("rinkeby"),
      ropsten: getChainConfig("ropsten"),
        
  },
  gasReporter: {
    currency: 'USD',
    token: 'ETH',
    gasPrice: 156,
    showMethodSig: true,
    showTimeSpent: true,
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },

  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },

  solidity: {
    compilers: [
        {
            version: "0.8.9",
            settings: {
                metadata: {
                    bytecodeHash: "none",
                },
                optimizer: {
                    enabled: true,
                    runs: 800,
                },
            },
        }
    ],
    settings: {
        outputSelection: {
            "*": {
                "*": ["storageLayout"],
            },
        },
    },
  },
  namedAccounts: {
    deployer: {
        default: 0,
        tokenOwner: 1,
    },
    // ownedWallets: {
    //     1: "0x245cc372C84B3645Bf0Ffe6538620B04a217988B",
    // },
},
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
    deploy: "./scripts/deploy",
    deployments: "./deployments",
},
  mocha: {
    timeout: 40000
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
    // only: [':ERC20$'],
    spacing: 2,
    // pretty: true,
  }
};

export default config;