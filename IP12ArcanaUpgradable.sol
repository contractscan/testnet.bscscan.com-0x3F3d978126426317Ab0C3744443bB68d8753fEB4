//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IP12ArcanaUpgradable {
  function getVotingPower(uint256 tokenId) view external returns (uint256);
}