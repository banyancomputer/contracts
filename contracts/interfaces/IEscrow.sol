// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.9;

interface IEscrow {
    /* ========== EVENTS ========== */

    event AuthorityUpdated(address authority);

    /* ========== VIEW ========== */

    function governor() external view returns (address);

    function vault() external view returns (address);
}
