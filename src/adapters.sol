/// adapters.sol -- Non-standard token adapters

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.0;

import "ds-note/note.sol";

contract Token3Like {
    function transfer(address,uint) public;
    function transferFrom(address,address,uint) public;
    function balanceOf(address) public view returns (uint);
    function allowance(address,address) public view returns (uint);
}

contract Token5Like {
    function decimals() public returns (uint);
    function transfer(address,uint) public returns (bool);
    function transferFrom(address,address,uint) public returns (bool);
}

contract VatLike {
    function slip(bytes32,bytes32,int) public;
}

/*
    Here we provide *adapters* to connect the Vat to arbitrary external
    token implementations, creating a bounded context for the Vat. The
    adapters here are provided as working examples:

        - `Token3Join`: For a token that does not return a bool on transfer or
                    transferFrom
        - `Token5Join`: For a token that has a lower precision

    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.

    Adapters need to implement two basic methods:

      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system

*/

// This is one way of doing it. Check the balances before and after calling a transfer
contract Token3Join is DSNote {
    VatLike public vat;
    bytes32 public ilk;
    Token3Like public gem;
    constructor(address vat_, bytes32 ilk_, address gem_) public {
        vat = VatLike(vat_);
        ilk = ilk_;
        gem = Token3Like(gem_);
    }
    function join(bytes32 urn, uint wad) public note {
        require(int(wad) >= 0, "");
        vat.slip(ilk, urn, int(wad));
        uint256 prevBalance = gem.balanceOf(msg.sender);

        require(prevBalance >= wad, "");
        require(gem.allowance(msg.sender, address(this)) >= wad, "");
        
        address(gem).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), wad)
        );

        require(prevBalance - wad == gem.balanceOf(msg.sender), "");
    }
    function exit(bytes32 urn, address guy, uint wad) public note {
        require(bytes20(urn) == bytes20(msg.sender), "");
        require(int(wad) >= 0, "");
        vat.slip(ilk, urn, -int(wad));
        uint256 prevBalance = gem.balanceOf(address(this));

        require(prevBalance >= wad, "");

        address(gem).call(
            abi.encodeWithSignature("transfer(address,uint256)", guy, wad)
        );

        require(prevBalance - wad == gem.balanceOf(address(this)), "");
    }
}

contract Token5Join is DSNote {
    VatLike public vat;
    bytes32 public ilk;
    Token5Like public gem;
    constructor(address vat_, bytes32 ilk_, address gem_) public {
        vat = VatLike(vat_);
        ilk = ilk_;
        gem = Token5Like(gem_);
        require(gem.decimals() < 18, "");
    }
    function join(bytes32 urn, uint wad) public note {
        uint wad18 = wad * 10 ** (18 - gem.decimals());
        require(int(wad18) >= 0, "");
        vat.slip(ilk, urn, int(wad18));
        require(gem.transferFrom(msg.sender, address(this), wad), "");
    }
    function exit(bytes32 urn, address guy, uint wad) public note {
        require(bytes20(urn) == bytes20(msg.sender), "");
        require(int(wad) >= 0, "");
        uint wad18 = wad * 10 ** (18 - gem.decimals());
        vat.slip(ilk, urn, -int(wad18));
        require(gem.transfer(guy, wad), "");
    }
}
