//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import 'hardhat/console.sol';
// import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
// import '@openzeppelin/contracts/metatx/ERC2771Context.sol';
// import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol';
// import '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import { Base64 } from '@openzeppelin/contracts/utils/Base64.sol';

import './interface/IP12ArcanaUpgradable.sol';
import './interface/IRenderEngine.sol';

contract P12ArcanaUpgradable is
  IP12ArcanaUpgradable,
  ERC2771ContextUpgradeable,
  OwnableUpgradeable,
  UUPSUpgradeable,
  ERC721Upgradeable,
  EIP712Upgradeable
{
  using ECDSAUpgradeable for bytes32;

  bytes32 private constant _TYPEHASH = keccak256('PowerUpdate(uint256 tokenId,uint256 power,uint256 deadline)');

  uint256 idx;

  //
  address public renderEngine;

  // signers
  mapping(address => bool) public signers;

  // voting powers
  mapping(uint256 => uint256) private _powers;

  // tokenId => ipfs uri
  mapping(uint256 => string) public answersUri;

  constructor(address forwarder_) ERC2771ContextUpgradeable(forwarder_) {}

  function initialize(
    string calldata name_,
    string calldata symbol_,
    string calldata version_
  ) public initializer {
    __Ownable_init_unchained();
    __ERC721_init_unchained(name_, symbol_);
    __EIP712_init_unchained(name_, version_);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address sender) {
    return ERC2771ContextUpgradeable._msgSender();
  }

  function _msgData() internal view virtual override(ERC2771ContextUpgradeable, ContextUpgradeable) returns (bytes calldata) {
    return ERC2771ContextUpgradeable._msgData();
  }

  //
  function getBattlePass() external {
    require(balanceOf(_msgSender()) == 0, 'P12Arcana: already have pass');

    _safeMint(_msgSender(), idx);
    idx += 1;
  }

  function getBattlePass(address user) external {
    require(balanceOf(user) == 0, 'P12Arcana: already have pass');

    _safeMint(user, idx);
    idx += 1;
  }

  function updateAnswerUri(uint256 tokenId, string calldata uri) external {
    require(ownerOf(tokenId) == _msgSender(), 'P12Arcana: not token owner');

    answersUri[tokenId] = uri;
  }

  function updatePower(
    uint256 tokenId,
    uint256 power,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(ownerOf(tokenId) == _msgSender(), 'P12Arcana: not token owner');
    require(deadline > block.timestamp, 'P12Arcana: outdated sig');

    address signer = _hashTypedDataV4(keccak256(abi.encode(_TYPEHASH, tokenId, power, deadline))).recover(signature);

    require(signers[signer] == true, 'P12Arcana: sig not from signer');

    _powers[tokenId] = power;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireMinted(tokenId);

    string memory SVG = IRenderEngine(renderEngine).renderTokenById(tokenId);

    string memory description = 'P12 Arcana MultiCast Vote';

    string memory metadata = Base64.encode(
      bytes(string.concat('{"name": "P12 Arcana MultiCast Vote","description":"', description, '","image":"', SVG, '"}'))
    );

    return string.concat('data:application/json;base64,', metadata);
  }

  function getVotingPower(uint256 tokenId) external view override returns (uint256) {
    return _powers[tokenId];
  }

  function setSigner(address signer, bool valid) external onlyOwner {
    signers[signer] = valid;
  }

  function setRenderEngin(address newEngine) external onlyOwner {
    renderEngine = newEngine;
  }

  modifier onlySigner() {
    require(signers[_msgSender()] == true, 'P12Arcana: not signer');
    _;
  }
}