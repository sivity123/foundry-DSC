// SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Invarient} from "src/Invarient.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
contract InvarientTest is Test{

Invarient invarient;
    function setUp() public {
        invarient = new Invarient();
        targetContract(address(invarient));
    }

    function testDoStuff() public {// Unit Testing
    uint256 data = 0;
    uint256 expectedValue = 0;
    invarient.doStuff(data);
    assertEq(expectedValue,invarient.s_shouldBeZero());
    }

    function testDoStuffWithStateless(uint256 data) public {// stateless fuzzing
    uint256 expectedValue = 0;
    invarient.doStuff(data);
    assertEq(expectedValue,invarient.s_shouldBeZero());
    }

    function invariant_testDoStuff()public view{
        assertEq(0,invarient.s_shouldBeZero());
    }
}