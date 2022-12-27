//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {

    address payable owner;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; //counters used from openzeppelin counters.sol to help count the Number of Tokens and Tokens Sold
    Counters.Counter private _itemsSold;

    uint256 listPrice=0.01 ether;  //the amount people have to pay to list their nfts

    constructor() ERC721("NFTMarketplace", "NFTM")
    {
        owner=payable(msg.sender); 
    }
    
    struct ListedToken 
    {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    mapping(uint256=>ListedToken) private idToListedToken; //creating a mapping of the tokenIds to the ListedToken structures that store the metadata of NFT

    function updateListPrice(uint256 _listPrice) public payable 
    {
        require(owner==msg.sender,"Only owner is allowed to update listing price");
        listPrice= _listPrice;

    }

    function getListPrice() public view returns (uint256) //fetch data from smart contract
    {
        return listPrice;
    }

    function getLatestIdToListedToken() public view returns(ListedToken memory) //just view function to fetch and can be called outside of smart contract (Stored in memory because in storage is too costly)
    {
        uint256 currentTokenId=_tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedForTokenId(uint256 tokenId) public view returns (ListedToken memory) //input token id and get listed token
    {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) 
    {
        require(msg.value==listPrice,"Send enough ether to list");
        require(price>0, "Make sure the price is in a positive value"); //check if the ether sent matches listing fee, and abort if the price is negative

        _tokenIds.increment();                          //after passing the checks, we increment the number of tokens and use the ERC721 functions _safeMint and _setTokenURI to mint and store URL 
        uint256 currentTokenId=_tokenIds.current();
        _safeMint(msg.sender,currentTokenId);
        _setTokenURI(currentTokenId,tokenURI);

        createListedToken(currentTokenId,price);       

        return currentTokenId;
    }


    function createListedToken(uint256 tokenId, uint256 price) private 
    {
        idToListedToken[tokenId]=ListedToken(           //add to the mapping of tokenIds to ListedTokens a new token, with the owner being the current address, and the seller as the caller of the function
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        _transfer(msg.sender, address(this),tokenId);  //transfer ownership token to the marketplace contract to make the process of selling easier
    }


    function getAllNFTs() public view returns(ListedToken[] memory) //a function to get all listed NFTs to the frontend. we get the number of nfts then we create an array Tokens of type ListedToken and run a loop to store all the mapped values of listed tokens to array and then return said array
    {
        uint nftCount=_tokenIds.current();
        ListedToken[] memory tokens= new ListedToken[](nftCount);

        uint currentIndex=0;

        for(uint i=0;i<nftCount;i++)
        {
            uint currentId=i+1;
            ListedToken storage currentItem=idToListedToken[currentId];
            tokens[currentIndex]=currentItem;
            currentIndex+=1;
        }

        return tokens; 
    }

    function getMyNFTs() public view returns(ListedToken [] memory) //function to filter NFT's that belong to the caller of the function
    {
        uint totalItemCount=_tokenIds.current();
        uint itemCount=0;
        uint currentIndex=0;


        for(uint i=0; i<totalItemCount; i++) //loop to get the count of the NFT's in order to declare an appropriately sized array
        {   
            if(idToListedToken[i].owner==msg.sender|| idToListedToken[i].seller== msg.sender){
                itemCount+=1;
            }
        }

        ListedToken[] memory items= new ListedToken[](itemCount); //we create an array of correct size and store the user's NFT's in it
        for(uint i=0; i< totalItemCount; i++) {
            if(idToListedToken[i].owner==msg.sender||idToListedToken[i].seller==msg.sender )
            {
                uint currentId=i+1;
                ListedToken storage currentItem=idToListedToken[currentId];
                items[currentIndex]=currentItem;
                currentIndex+=1;
            }
        }
    }

    function executeSale(uint256 tokenId) public payable
    {
        uint price=idToListedToken[tokenId].price;
        require(msg.value==price,"Please pay the correct amount to commence with purchase");

        address seller=idToListedToken[tokenId].seller;

        idToListedToken[tokenId].currentlyListed=true;
        idToListedToken[tokenId].seller=payable(msg.sender);
        _itemsSold.increment();

        _transfer(address(this),msg.sender,tokenId);

        approve(address(this),tokenId); //user approves permission to the marketplace for NFT sale

        payable(owner).transfer(listPrice);
        payable(seller).transfer(msg.value);
    }

}