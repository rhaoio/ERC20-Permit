//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Permits is Ownable{

    bytes32 public DOMAIN_SEPARATOR;

    mapping(address => uint) public nonces; //track permits of tokens
    mapping(address => bytes32) public DOMAIN_SEPARATORS;

    uint chainId;

    constructor() {
        chainId = 1337; //solidity docs 1337 = hardhat
    }

    function createDomainSep(address _tokenAddress) public onlyOwner {
        ERC20 TokenContract = ERC20(_tokenAddress); 
        //TODO: Insert Require for existance of contract;
        DOMAIN_SEPARATORS[_tokenAddress] = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(TokenContract.name())), // ERC-20 Name
                keccak256(bytes("1")),    // Version
                chainId, //ID of the chain to prevent cross chain usage of signature
                _tokenAddress
            )
        );
    }
        
    


    
    function permitToken (
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address tokenAddress) external {
            require(deadline >= block.timestamp, "Deadline expired");
            createDomainSep(tokenAddress);
            bytes32 permitDigest = keccak256(
                abi.encodePacked(
                    uint16(0x1901),
                    DOMAIN_SEPARATORS[tokenAddress],
                    keccak256(abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonces[tokenAddress],
                        deadline))
            ));
            address validAddress = ecrecover(permitDigest, v, r, s); //check for valid address and not falsified
            console.log("validAddress %s", validAddress);
            require(validAddress != address(0) && validAddress == owner, "Signature invalid");
            nonces[tokenAddress]++;
            ERC20 TokenContract = ERC20(tokenAddress); 
            TokenContract.approve(spender, value); // This does not work, as msg.sender is this contract...
        }

    function _nonces(address _tokenAddress) external view returns (uint256) {
        return nonces[_tokenAddress];
    }
}