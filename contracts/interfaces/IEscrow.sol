// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.9;

interface IEscrow {
    /* ========== EVENTS ========== */

    event AuthorityUpdated(address authority);

    /* ========== VIEW ========== */

    function admin() external view returns (address);
    
}
