// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Kernel, Policy, Permissions, Keycode} from "@src/Kernel.sol";
import {toKeycode} from "@src/libraries/KernelUtils.sol";
import {Storage} from "@src/modules/Storage.sol";
import {PaymentEscrow} from "@src/modules/PaymentEscrow.sol";

/**
 * @title Admin
 * @notice Acts as an interface for all behavior in the protocol related
 *         admin logic. Admin duties include fee management, proxy management,
 *         and whitelist management.
 */
contract Admin is Policy {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    // Modules that the policy depends on.
    Storage public STORE;
    PaymentEscrow public ESCRW;

    /**
     * @dev Instantiate this contract as a policy.
     *
     * @param kernel_ Address of the kernel contract.
     */
    constructor(Kernel kernel_) Policy(kernel_) {}

    /**
     * @notice Upon policy activation, configures the modules that the policy depends on.
     *         If a module is ever upgraded that this policy depends on, the kernel will
     *         call this function again to ensure this policy has the current address
     *         of the module.
     *
     * @return dependencies Array of keycodes which represent modules that
     *                      this policy depends on.
     */
    function configureDependencies()
        external
        override
        onlyKernel
        returns (Keycode[] memory dependencies)
    {
        dependencies = new Keycode[](2);

        dependencies[0] = toKeycode("STORE");
        STORE = Storage(getModuleAddress(toKeycode("STORE")));

        dependencies[1] = toKeycode("ESCRW");
        ESCRW = PaymentEscrow(getModuleAddress(toKeycode("ESCRW")));
    }

    /**
     * @notice Upon policy activation, permissions are requested from the kernel to access
     *         particular keycode <> function selector pairs. Once these permissions are
     *         granted, they do not change and can only be revoked when the policy is
     *         deactivated by the kernel.
     *
     * @return requests Array of keycode <> function selector pairs which represent
     *                  permissions for the policy.
     */
    function requestPermissions()
        external
        view
        override
        onlyKernel
        returns (Permissions[] memory requests)
    {
        requests = new Permissions[](22);
        requests[0] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistExtension.selector
        );
        requests[1] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistDelegate.selector
        );
        requests[2] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistAsset.selector
        );
        requests[3] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistAssetBatch.selector
        );
        requests[4] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistPayment.selector
        );
        requests[5] = Permissions(
            toKeycode("STORE"),
            STORE.toggleWhitelistPaymentBatch.selector
        );
        requests[6] = Permissions(toKeycode("STORE"), STORE.upgrade.selector);
        requests[7] = Permissions(toKeycode("STORE"), STORE.freeze.selector);
        requests[8] = Permissions(toKeycode("STORE"), STORE.setMaxRentDuration.selector);
        requests[9] = Permissions(toKeycode("STORE"), STORE.setMaxOfferItems.selector);
        requests[10] = Permissions(
            toKeycode("STORE"),
            STORE.setMaxConsiderationItems.selector
        );
        requests[11] = Permissions(
            toKeycode("STORE"),
            STORE.setGuardEmergencyUpgrade.selector
        );

        requests[12] = Permissions(toKeycode("ESCRW"), ESCRW.skim.selector);
        requests[13] = Permissions(toKeycode("ESCRW"), ESCRW.setFee.selector);
        requests[14] = Permissions(toKeycode("ESCRW"), ESCRW.upgrade.selector);
        requests[15] = Permissions(toKeycode("ESCRW"), ESCRW.freeze.selector);

        requests[16] = Permissions(toKeycode("STORE"), STORE.blacklistUser.selector);
        requests[17] = Permissions(toKeycode("STORE"), STORE.unblacklistUser.selector);
        requests[18] = Permissions(toKeycode("STORE"), STORE.applyFine.selector);
        requests[19] = Permissions(toKeycode("STORE"), STORE.issueWarning.selector);
        requests[20] = Permissions(toKeycode("STORE"), STORE.banUser.selector);
        requests[21] = Permissions(toKeycode("STORE"), STORE.clearFine.selector);

        
    }

    // ///////////////////////////////////////////////////////////////////////////////
    //                            Punishment Logic                                 //
    // ///////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Enforce punishment based on similarity score.
     *
     * @param user Address of the user to be punished.
     * @param similarityScore The similarity score of the NFT in question.
     */
    function enforcePunishment(address user, uint256 similarityScore) external onlyRole("ADMIN_ADMIN") {
        if (similarityScore >= 80) {
            // 80%+ similarity: blacklist the user
            STORE.blacklistUser(user);
        } else if (similarityScore >= 50) {
            // 50%-79% similarity: fine and temporary ban
            STORE.applyFine(user, 1 ether); // Example fine amount, can be adjusted
            STORE.banUser(user, 30 days); // Example ban duration, can be adjusted
        } else if (similarityScore >= 30) {
            // 30%-49% similarity: issue a warning
            STORE.issueWarning(user);
        }
    }
    /**
     * @notice Clear a user's record after they have served their punishment or appealed successfully.
     *
     * @param user Address of the user to clear the record for.
     */
    function clearUserRecord(address user) external onlyRole("ADMIN_ADMIN") {
        STORE.clearFine(user);
        STORE.unblacklistUser(user);
    }

    /**
     * @notice Check if a user is currently blacklisted.
     *
     * @param user Address of the user to check.
     * @return bool True if the user is blacklisted, false otherwise.
     */
    function isUserBlacklisted(address user) external view returns (bool) {
        return STORE.blacklistedUsers(user);
    }

    /**
     * @notice Check if a user is currently banned.
     *
     * @param user Address of the user to check.
     * @return bool True if the user is currently banned, false otherwise.
     */
    function isUserBanned(address user) external view returns (bool) {
        return STORE.isUserBanned(user);
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                            External Functions                               //
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Toggle whether an address can be delegate called by a rental safe.
     *
     * @param delegate  Target address for the delegate call.
     * @param isEnabled Whether the address can be delegate called.
     */
    function toggleWhitelistDelegate(
        address delegate,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistDelegate(delegate, isEnabled);
    }

    /**
     * @notice Updates an extension with a bitmap that indicates whether the extension
     *         can be enabled or disabled by the rental safe. A valid bitmap is any
     *         decimal value that is less than or equal to 3 (0x11).
     *
     * @param extension Gnosis safe module which can be added to a rental safe.
     * @param bitmap    Decimal value that defines the status of the extension.
     */
    function toggleWhitelistExtension(
        address extension,
        uint8 bitmap
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistExtension(extension, bitmap);
    }

    /**
     * @notice Toggles whether a token can be rented.
     *
     * @param asset  Token address which can be rented via the protocol.
     * @param bitmap Bitmap that denotes whether an asset can be rented.
     */
    function toggleWhitelistAsset(
        address asset,
        uint8 bitmap
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistAsset(asset, bitmap);
    }

    /**
     * @notice Toggles whether a batch of tokens can be rented.
     *
     * @param assets  Token array which can be rented via the protocol.
     * @param bitmaps Bitmap array indicating whether those assets can be rented.
     */
    function toggleWhitelistAssetBatch(
        address[] memory assets,
        uint8[] memory bitmaps
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistAssetBatch(assets, bitmaps);
    }

    /**
     * @notice Toggles whether a token can be used as a payment.
     *
     * @param payment   Token address which can be used as payment via the protocol.
     * @param isEnabled Whether the token is whitelisted for payment.
     */
    function toggleWhitelistPayment(
        address payment,
        bool isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistPayment(payment, isEnabled);
    }

    /**
     * @notice Toggles whether a batch of tokens can be used as payment.
     *
     * @param payments  Token array which can be used as payment via the protocol.
     * @param isEnabled Boolean array indicating whether those token are whitelisted.
     */
    function toggleWhitelistPaymentBatch(
        address[] memory payments,
        bool[] memory isEnabled
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.toggleWhitelistPaymentBatch(payments, isEnabled);
    }

    /**
     * @notice Upgrades the storage module to a newer implementation. The new
     *         implementation contract must adhere to ERC-1822.
     *
     * @param newImplementation Address of the new implemention.
     */
    function upgradeStorage(address newImplementation) external onlyRole("ADMIN_ADMIN") {
        STORE.upgrade(newImplementation);
    }

    /**
     * @notice Freezes the storage module so that no proxy upgrades can take place. This
     *         action is non-reversible.
     */
    function freezeStorage() external onlyRole("ADMIN_ADMIN") {
        STORE.freeze();
    }

    /**
     * @notice Upgrades the payment escrow module to a newer implementation.
     *         The new implementation contract must adhere to ERC-1822.
     *
     * @param newImplementation Address of the new implemention.
     */
    function upgradePaymentEscrow(
        address newImplementation
    ) external onlyRole("ADMIN_ADMIN") {
        ESCRW.upgrade(newImplementation);
    }

    /**
     * @notice Freezes the payment escrow module so that no proxy upgrades can take
     *         place. This action is non-reversible.
     */
    function freezePaymentEscrow() external onlyRole("ADMIN_ADMIN") {
        ESCRW.freeze();
    }

    /**
     * @notice Skims all protocol fees from the escrow module to the target address.
     *
     * @param token Token address which denominates the fee.
     * @param to    Destination address to send the tokens.
     */
    function skim(address token, address to) external onlyRole("ADMIN_ADMIN") {
        ESCRW.skim(token, to);
    }

    /**
     * @notice Sets the protocol fee numerator. Numerator cannot be greater than 10,000.
     *
     * @param feeNumerator Numerator for the fee.
     */
    function setFee(uint256 feeNumerator) external onlyRole("ADMIN_ADMIN") {
        ESCRW.setFee(feeNumerator);
    }

    /**
     * @notice Sets the maximum rent duration.
     *
     * @param newDuration The new maximum rent duration.
     */
    function setMaxRentDuration(uint256 newDuration) external onlyRole("ADMIN_ADMIN") {
        STORE.setMaxRentDuration(newDuration);
    }

    /**
     * @notice Sets the maximum offer items for a single order.
     *
     * @param newOfferLength The new maximum number of offer items.
     */
    function setMaxOfferItems(uint256 newOfferLength) external onlyRole("ADMIN_ADMIN") {
        STORE.setMaxOfferItems(newOfferLength);
    }

    /**
     * @notice Sets the maximum consideration items for a single order.
     *
     * @param newConsiderationLength The new maximum number of consideration items.
     */
    function setMaxConsiderationItems(
        uint256 newConsiderationLength
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.setMaxConsiderationItems(newConsiderationLength);
    }

    /**
     * @notice Sets the guard emergency upgrade address.
     *
     * @param guardEmergencyUpgradeAddress The contract address which will allow rental
     * 									   safes to upgrade their guard policy.
     */
    function setGuardEmergencyUpgrade(
        address guardEmergencyUpgradeAddress
    ) external onlyRole("ADMIN_ADMIN") {
        STORE.setGuardEmergencyUpgrade(guardEmergencyUpgradeAddress);
    }
}
