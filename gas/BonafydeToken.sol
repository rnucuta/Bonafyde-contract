// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

// import "erc721a/contracts/ERC721A.sol";
import "erc721psi/contracts/ERC721Psi.sol"

// import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/token/ERC721/ERC721.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";



// Need to implement gas costs adjustment (https://github.com/AboldUSER/ERC721A)
// Deploy NFT on a test net (https://ropsten.rarible.com/) and use the Rarible Marketplace UI to make sure everything works properly
// https://medium.com/rarible-dao/rarible-nft-royalties-in-your-custom-smart-contract-b07550e89ef4

//https://wizard.openzeppelin.com/#erc721

contract BonafydeToken is ERC721Psi, Ownable, RoyaltiesV2Impl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (uint => uint) public tokenLockedFromTimestamp;
    mapping (uint => bytes32) public tokenUnlockCodeHashes;
    mapping (uint => bool) public tokenUnlocked;
    event TokenUnlocked(uint tokenId, address unlockerAddress);

    //Mintablex 
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    constructor() ERC721Psi("BonafydeToken", "BFT") {}

    // "https://bonafyde.io/metadata/"

    function _beforeTokenTransfers(address from, address to, uint256 tokenIdBatchHead, uint256 quantity) internal override {
        for(uint256 tokenId=tokenIdBatchHead;tokenId < tokenIdBatchHead + quantity; tokenId++){
            require(tokenLockedFromTimestamp[tokenId] > block.timestamp || tokenUnlocked[tokenId], "BonafydeToken: Token locked");
        }
        
        // super._beforeTokenTransfer(from, to, tokenId);
    }

    function unlockToken(bytes32 unlockHash, uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "BonafydeToken: Only the Owner can unlock the Token"); //not 100% sure about that one yet
        require(keccak256(abi.encode(unlockHash)) == tokenUnlockCodeHashes[tokenId], "BonafydeToken: Unlock Code Incorrect");
        tokenUnlocked[tokenId] = true;
        emit TokenUnlocked(tokenId, msg.sender);
    }

    /**
    * This one is the mint function that sets the unlock code, then calls the parent mint
    */

    //must have different unlock hash for each coin, but gas saving algorithm mints coins together...

    function mint(address to, uint256 quantity, mapping (uint => uint) lockedFromTimestamps, mapping (uint => bytes32) unlockHashes) external payable onlyOwner{
        // _safeMint's second argument now takes in a quantity, not a tokenId. (same as ERC721A)
        _mint(msg.sender, quantity);
        for(uint256 tokenId=tokenIdBatchHead;tokenId < tokenIdBatchHead + quantity; tokenId++){
            tokenLockedFromTimestamp[tokenId] = lockedFromTimestamps[tokenId];
            tokenUnlockCodeHashes[tokenId] = unlockHashes[tokenId];
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://bonafyde.io/metadata/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Psi: URI query for nonexistent token");
        return string(abi.encodePacked(super.tokenURI(tokenId),".json"));
    }

    //Royalties
    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    //Mintable
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if(_royalties.length > 0) {
            return (_royalties[0].account, (_salePrice * _royalties[0].value)/10000);
        }
        return (address(0), 0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Psi) returns (bool) {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        //Mintable
        if(interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    } 
}