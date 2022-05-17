// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
require("dotenv").config();
const bn = require("bn.js");
const hre = require("hardhat");
const ethers = hre.ethers;

//Constants for this token and setup - currently just pasted from deploy output
const tokenAddress = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
const hardhatChainId = 1337;

//TYPES for EIP2612 - it is handled in ethers _signTypedData https://github.com/ethers-io/ethers.js/issues/687
const EIP712Domain = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" },
];

const Permit = [
  { name: "owner", type: "address" },
  { name: "spender", type: "address" },
  { name: "value", type: "uint256" },
  { name: "nonce", type: "uint256" },
  { name: "deadline", type: "uint256" },
];

//Create the EIP2612 message to be signed which contains Permit function and params
const createEIP2612Message = (
  owner,
  spender,
  value,
  nonce,
  deadline,
  name,
  version,
  chainId,
  verifyingContract
) => {
  const domain = {
    name,
    version,
    chainId,
    verifyingContract,
  };
  const message = {
    owner,
    spender,
    value,
    nonce,
    deadline,
  };

  const types = {
    Permit,
  };

  const data = {
    types: types,
    primaryType: "Permit",
    domain,
    message,
  };
  const result = {
    domain: domain,
    types: types,
    message: message,
  };

  return data;
};

async function main() {
  //get the 2 accounts/wallets we will test with, should be the same when running npx hardhat node every time.
  const [account0, account1] = await ethers.getSigners();
  //get the current provider
  const provider = ethers.provider;
  //get a reference to our token contract which is already deployed on our local node.
  const Token = await ethers.getContractFactory("Permit");
  const contract = Token.attach(tokenAddress);

  //address values for our test wallets
  const addr0 = account0.address;
  const addr1 = account1.address;

  console.log(addr0, addr1);

  //Token Balances of our test wallets (should be 1000 and 0 after minting at deployment)
  let balance0 = await contract.balanceOf(addr0);
  let balance1 = await contract.balanceOf(addr1);

  //Eth balances of each test wallet.
  const ethBal0 = await provider.getBalance(addr0);
  const ethBal1 = await provider.getBalance(addr1);
  console.log(ethBal0, balance0, "Balances 0");
  console.log(ethBal1, balance1, "Balances 1");

  //We need to get the time frame of the signature/permit
  let currTime = new Date(Date.now());

  //Add one hour to the current time
  currTime.setHours(currTime.getHours() + 1);

  //Convert to unix time
  currTime = Math.floor(new Date(currTime).getTime() / 1000);

  //Setup parameters for our message and verification
  let nonce = await contract._nonces(addr0);
  nonce = nonce.toNumber(); //(BigNumber to JS number)

  //Token name, grab from ERC-20 Contract
  let name = await contract.name();
  //Grab current chain id, in production would grab this from the provider.
  let chainId = hardhatChainId;
  console.log(nonce, name, chainId, "nonce", "name", "chainId");

  //Create our msg structure to sign. Should contain:
  //domain info,
  //our types (Permit function) and
  //the message/data we are signing (Permit parameters)
  const msg = createEIP2612Message(
    addr0,
    addr1,
    50,
    nonce,
    currTime,
    name,
    "1",
    chainId,
    tokenAddress
  );
  console.log(msg);

  //sign the data using ethers.js library, it will set the EIP712 domain within the lib itself.
  let sig = await account0._signTypedData(msg.domain, msg.types, msg.message);
  console.log(sig, "Signed Message sig");
  //Split the signature into our r,s and v values for verification
  let expanded = ethers.utils.splitSignature(sig);
  console.log(expanded, "expanded sig");

  //set our verification points here.
  const r = expanded.r;
  const s = expanded.s;
  const v = expanded.v;

  //Call the Permit function to test!
  //Ensure to connect/use our 2nd test wallet which is not the original signer!
  const tx = await contract
    .connect(account1)
    .permit(addr0, addr1, 50, currTime, v, r, s);

  console.log(tx);

  //Check allowances
  const allowance = await contract.allowance(addr0, addr1);
  console.log("ALLOWANCE", allowance);

  console.log("Balances Before Transfer");
  console.log(ethBal0, balance0, "Balances 0");
  console.log(ethBal1, balance1, "Balances 1");
  //Test the transfer from the second wallet
  //transferFrom function is used when transfering as the 'spender' and not the 'owner'
  await contract.connect(account1).transferFrom(addr0, addr1, 10);

  balance0 = await contract.balanceOf(addr0);
  balance1 = await contract.balanceOf(addr1);
  console.log("Balances After Transfer");

  console.log(ethBal0, balance0, "Balances 0");
  console.log(ethBal1, balance1, "Balances 1");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
