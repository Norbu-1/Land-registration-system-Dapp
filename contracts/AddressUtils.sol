// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

library AddressUtils {
    function isContract(address _address) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }
    
    // Add more address validation functions as needed
}
