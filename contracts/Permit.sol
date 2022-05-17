//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Permit is ERC20 {

    bytes32 public DOMAIN_SEPARATOR;

    mapping(address => uint) public nonces; //track permits of accounts 

    constructor() ERC20("PolygonPermit", "POLY"){

        _mint(msg.sender, 1000);

        uint chainId = 1337; //solidity docs 1337 = hardhat

        DOMAIN_SEPARATOR = keccak256(
        abi.encode(
            keccak256(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            ),
            keccak256(bytes(name())), // ERC-20 Name
            keccak256(bytes("1")),    // Version
            chainId, //ID of the chain to prevent cross chain usage of signature
            address(this)
        ));
    }
        
    

    ///@dev https://eips.ethereum.org/EIPS/eip-2612

    //permit function which takes 

    //function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external
    //function nonces(address owner) external view returns (uint)
    //function DOMAIN_SEPARATOR() external view returns (bytes32)
    ///@dev
    ///for all addresses (owner and spender), uint256 (value, deadline, nonce), uint8(v), bytes32(r,s), 
    ///calling permit with these inputs will set approval[owner][spender] to value, increment nonces[owner] by 1
    //and emit an Approval event if and only if the following conditions are met.

    ///- the current blocktime is less than or equal to `deadline`
    ///- owner is not zero address
    ///- nonces[owner] is equal to nonce. (one at a time, track approvals)
    ///- r, s and v is a valid secp256k1 signature from `owner` of the message
    function verifySig( 
        bytes32 num, 
        address owner,
        uint8 v,
        bytes32 r,
        bytes32 s) external view {

            bytes32 numDigest = keccak256(abi.encodePacked(num));
            

            address validAddress = ecrecover(numDigest, v, r, s); //check for valid address and not falsified
            require(owner == validAddress, "Invalid Sig");
            console.log("Success");
        }
    
    function permit (
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s) external {
            require(deadline >= block.timestamp, "Deadline expired");
            bytes32 permitDigest = keccak256(
                abi.encodePacked(
                    uint16(0x1901),
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner,
                        spender,
                        value,
                        nonces[owner],
                        deadline))
            ));
            console.log("owner %s", owner);
            console.log("spender %s", spender);
            console.log("value %s", value);
            console.log("deadline %s", deadline);
            

            address validAddress = ecrecover(permitDigest, v, r, s); //check for valid address and not falsified
            console.log("validAddress %s", validAddress);
            require(validAddress != address(0) && validAddress == owner, "Signature invalid");
            nonces[owner]++;
            _approve(owner, spender, value);
        }

    function _nonces(address _owner) external view returns (uint256) {
        return nonces[_owner];
    }
}