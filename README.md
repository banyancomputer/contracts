# Contracts

Banyan Contracts

[![Escrow Contract CI](https://github.com/banyancomputer/contracts/actions/workflows/node.js.yml/badge.svg)](https://github.com/banyancomputer/contracts/actions/workflows/node.js.yml)


## 🔧 Setting up local development

### Requirements

- [Node v16](https://nodejs.org/download/release/latest-v16.x/)  
- [Git](https://git-scm.com/downloads)

### Local Setup Steps

```sh
# Clone the repository
git clone https://github.com/banyancomputer/contracts.git

# Install dependencies
npm install

# Set up environment variables (keys) and add your private keys
cp .env.example .env # (linux)
copy .env.example .env # (windows)

### Hardhat usage:
## Just Compile: 
npx hardhat compile

## Deploy locally: 
# Dry deployment: 
npx hardhat deploy

# With node running:
npx hardhat node

# Connect with console:
npx hardhat console --network localhost

## Compile and Deploy to Rinkeby:
npx hardhat deploy --network rinkeby

## Test: 
npx hardhat test

# Generate typescript files
npx hardhat typechain

# Clean artifacts (doesn't need to be versioned):
npx hardhat clean
```

### Notes for `localhost`
-   The `deployments/localhost` directory is included in the git repository,
    so that the contract addresses remain constant. Otherwise, the frontend's
    `constants.ts` file would need to be updated.
-   Avoid committing changes to the `deployments/localhost` files (unless you
    are sure), as this will alter the state of the hardhat node when deployed
    in tests.

## 📖 Guides
- Check out `./test/test.ts` for a full example of how to interact with the contract.

### Contracts
- [Rinkeby Addresses](./docs/deployments/rinkeby.md)

