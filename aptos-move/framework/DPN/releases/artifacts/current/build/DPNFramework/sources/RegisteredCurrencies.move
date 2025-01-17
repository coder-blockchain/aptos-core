/// Module for registering currencies in Diem. Basically, this means adding a
/// string (vector<u8>) for the currency name to vector of names in Reconfiguration.
module DiemFramework::RegisteredCurrencies {
    use DiemFramework::Reconfiguration;
    use DiemFramework::Timestamp;
    use DiemFramework::Roles;
    use Std::Errors;
    use Std::Vector;

    /// A Reconfiguration config holding all of the currency codes for registered
    /// currencies. The inner vector<u8>'s are string representations of
    /// currency names.
    struct RegisteredCurrencies has copy, drop, store {
        currency_codes: vector<vector<u8>>,
    }

    /// Attempted to add a currency code that is already in use
    const ECURRENCY_CODE_ALREADY_TAKEN: u64 = 0;

    /// Initializes this module. Can only be called from genesis, with
    /// a Diem root signer.
    public fun initialize(dr_account: &signer) {
        Timestamp::assert_genesis();
        Roles::assert_diem_root(dr_account);
        Reconfiguration::publish_new_config(
            dr_account,
            RegisteredCurrencies { currency_codes: Vector::empty() }
        );
    }
    spec initialize {
        include InitializeAbortsIf;
        include InitializeEnsures;
    }

    spec schema InitializeAbortsIf {
        dr_account: signer;
        include Timestamp::AbortsIfNotGenesis;
        include Roles::AbortsIfNotDiemRoot{account: dr_account};
        include Reconfiguration::PublishNewConfigAbortsIf<RegisteredCurrencies>;
    }
    spec schema InitializeEnsures {
        include Reconfiguration::PublishNewConfigEnsures<RegisteredCurrencies>{
            payload: RegisteredCurrencies { currency_codes: Vector::empty() }
        };
        ensures len(get_currency_codes()) == 0;
    }

    /// Adds a new currency code. The currency code must not yet exist.
    public fun add_currency_code(
        dr_account: &signer,
        currency_code: vector<u8>,
    ) {
        let config = Reconfiguration::get<RegisteredCurrencies>();
        assert!(
            !Vector::contains(&config.currency_codes, &currency_code),
            Errors::invalid_argument(ECURRENCY_CODE_ALREADY_TAKEN)
        );
        Vector::push_back(&mut config.currency_codes, currency_code);
        Reconfiguration::set(dr_account, config);
    }
    spec add_currency_code {
        include AddCurrencyCodeAbortsIf;
        include AddCurrencyCodeEnsures;
    }
    spec schema AddCurrencyCodeAbortsIf {
        dr_account: &signer;
        currency_code: vector<u8>;
        include Reconfiguration::SetAbortsIf<RegisteredCurrencies>{ account: dr_account };
        /// The same currency code can be only added once.
        aborts_if contains(
            Reconfiguration::get<RegisteredCurrencies>().currency_codes,
            currency_code
        ) with Errors::INVALID_ARGUMENT;
    }
    spec schema AddCurrencyCodeEnsures {
        currency_code: vector<u8>;
        // The resulting currency_codes is the one before this function is called, with the new one added to the end.
        ensures Vector::eq_push_back(get_currency_codes(), old(get_currency_codes()), currency_code);
        include Reconfiguration::SetEnsures<RegisteredCurrencies> {payload: Reconfiguration::get<RegisteredCurrencies>()};
    }

    // =================================================================
    // Module Specification

    spec module {} // switch documentation context back to module level

    /// # Initialization

    spec module {
        /// Global invariant that currency config is always available after genesis.
        invariant [suspendable] Timestamp::is_operating() ==> Reconfiguration::spec_is_published<RegisteredCurrencies>();
    }

    /// # Helper Functions

    spec module {
        /// Helper to get the currency code vector.
        fun get_currency_codes(): vector<vector<u8>> {
            Reconfiguration::get<RegisteredCurrencies>().currency_codes
        }
    }
}
