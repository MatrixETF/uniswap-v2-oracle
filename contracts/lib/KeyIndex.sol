// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;

import "./Bits.sol";
import "@nomiclabs/buidler/console.sol";


/**
 * @dev Library for indexing keys stored in a sequential mapping for easier
 * queries.
 *
 * Every set of 256 keys in the value map is assigned a single index which
 * records set values as bits, where 1 indicates the map has a value at a given
 * key and 0 indicates it does not.
 *
 * The 'value map' is the map which stores the values with sequential keys.
 * The 'key index' is the map which records the indices for every 256 keys
 * in the value map.
 *
 * The 'key index' is the mapping which stores the indices for each 256 values
 * in the map. For example, the key '256' in the value map would have a key
 * in the key index of `1`, where the 0th bit in the index records whether a
 * value is set in the value map .
 */
library KeyIndex {
  using Bits for uint256;

/* ========= Utility Functions ========= */

  /**
   * @dev Compute the map key for a given index key and position.
   * Multiplies indexKey by 256 and adds indexPosition.
   */
  function toMapKey(uint256 indexKey, uint256 indexPosition) internal pure returns (uint256) {
    return (indexKey * 256) + indexPosition;
  }

  /**
   * @dev Returns the key in the key index which stores the index for the 256-bit
   * index which includes `mapKey` and the position in the index for that key.
   */
  function indexKeyAndPosition(uint256 mapKey)
    internal
    pure
    returns (uint256 indexKey, uint256 indexPosition)
  {
    indexKey = mapKey / 256;
    indexPosition = mapKey % 256;
  }

/* ========= Mutative Functions ========= */

  /**
   * @dev Sets a bit at the position in `indexMap` corresponding to `mapKey` if the
   * bit is not already set.
   *
   * @param keyIndex Mapping with indices of set keys in the value map
   * @param mapKey Position in the value map to mark as set
   */
  function markSetKey(
    mapping(uint256 => uint256) storage keyIndex,
    uint256 mapKey
  ) internal returns (bool /* didSetKey */) {
    (uint256 indexKey, uint256 indexPosition) = indexKeyAndPosition(mapKey);
    // console.log("IPOS", indexPosition);
    uint256 localIndex = keyIndex[indexKey];
    bool canSetKey = !localIndex.bitSet(indexPosition);
    if (canSetKey) {
      keyIndex[indexKey] = localIndex.setBit(indexPosition);
    }
    return canSetKey;
  }

/* ========= View Functions ========= */

  function hasKey(
    mapping(uint256 => uint256) storage keyIndex,
    uint256 mapKey
  ) internal view returns (bool) {
    (uint256 indexKey, uint256 indexPosition) = indexKeyAndPosition(mapKey);
    uint256 localIndex = keyIndex[indexKey];
    if (localIndex == 0) return false;
    return localIndex.bitSet(indexPosition);
  }

  /**
   * @dev Find the most recent position before `mapKey` which the index map records
   * as having a set value. Returns the key in the value map for that position.
   *
   * @param keyIndex Mapping with indices of set keys in the value map
   * @param mapKey Position in the value map to look behind
   * @param maxDistance Maximum distance between the found value and `mapKey`
   */
  function findLastSetKey(
    mapping(uint256 => uint256) storage keyIndex,
    uint256 mapKey,
    uint256 maxDistance
  )
    internal
    view
    returns (bool/* found */, uint256/* mapKey */)
  {
    (uint256 indexKey, uint256 indexPosition) = indexKeyAndPosition(mapKey);
    uint256 distance = 0;
    bool found;
    uint256 position;
    uint256 localIndex;
    // If the position is 0, we must go to the previous index
    if (indexPosition == 0) {
      require(indexKey != 0, "KeyIndex::findLastSetKey:Can not query value prior to 0.");
      indexKey -= 1;
      distance = 1;
    } else {
      localIndex = keyIndex[indexKey];
      (found, position) = localIndex.nextLowestBitSet(indexPosition);
      if (found) {
        distance += indexPosition - position;
      } else {
        distance += indexPosition + 1;
        indexKey -= 1;
      }
    }

    while (!found && distance <= maxDistance) {
      localIndex = keyIndex[indexKey];
      if (localIndex == 0) {
        if (indexKey == 0) return (false, 0);
        distance += 256;
        indexKey -= 1;
      } else {
        position = localIndex.highestBitSet();
        distance += 255 - position;
        found = true;
      }
    }
    if (distance > maxDistance) {
      return (false, 0);
    }
    return (true, toMapKey(indexKey, position));
  }

  /**
   * @dev Find the next position after `mapKey` which the index map records as
   * having a set value. Returns the key in the value map for that position.
   *
   * @param keyIndex Mapping with indices of set values in the value map
   * @param mapKey Position in the value map to look ahead
   * @param maxDistance Maximum distance between the found value and `mapKey`
   */
  function findNextSetKey(
    mapping(uint256 => uint256) storage keyIndex,
    uint256 mapKey,
    uint256 maxDistance
  )
    internal
    view
    returns (bool/* found */, uint256/* mapKey */)
  {
    (uint256 indexKey, uint256 indexPosition) = indexKeyAndPosition(mapKey);
    uint256 distance = 0;
    bool found;
    uint256 position;
    uint256 localIndex;
    if (indexPosition == 255) {
      indexKey += 1;
      position = indexPosition;
      distance = 1;
    } else {
      localIndex = keyIndex[indexKey];
      (found, position) = localIndex.nextHighestBitSet(indexPosition);
      if (found) {
        distance += position - indexPosition;
      } else {
        distance += 256 - indexPosition;
        indexKey += 1;
      }
    }
    while (!found && distance <= maxDistance) {
      localIndex = keyIndex[indexKey];
      if (localIndex == 0) {
        distance += 256;
        indexKey += 1;
      } else {
        position = localIndex.lowestBitSet();
        distance += position;
        found = true;
      }
    }
    if (distance > maxDistance) {
      return (false, 0);
    }
    return (true, toMapKey(indexKey, position));
  }
}
