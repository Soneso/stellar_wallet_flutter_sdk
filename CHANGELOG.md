## [1.1.6] - 01.Oct.2026.
- update to `stellar_flutter_sdk` 3.8.0
- SEP-29: `Stellar.submitTransaction`, `submitWithFeeIncrease` and `submitWithFeeIncreaseAndSignerFunction` now run the memo-required check of `stellar_flutter_sdk` before submitting. A transaction without a memo that pays, path-pays or merges into an account whose `config.memo_required` data entry is `1` throws `AccountRequiresMemoException` and is not submitted
- SEP-29: for a memo-less transaction, the check makes up to one Horizon lookup per distinct non-muxed payment, path-payment or account-merge destination, in operation order, stopping on the first memo requirement or lookup failure. A 404 is skipped. Other failures propagate without posting: `ErrorResponse` for an HTTP error, `TooManyRequestsException` for a rate limit, `http.ClientException` for a transport failure, or a decoding error such as `FormatException` or `TypeError` for a malformed account response. `TypeError` is not caught by `on Exception catch`. To submit without the check, call `submitTransaction` or `submitFeeBumpTransaction` of `stellar.server` with `skipMemoRequiredCheck: true`. These return the `SubmitTransactionResponse` directly, without the wallet's `TransactionSubmitFailedException` mapping and timeout retry
- `Stellar.decodeTransaction` refuses malformed envelopes with defined errors: a negative array count throws `RangeError`, a zero price denominator in an offer or liquidity pool deposit operation throws `ArgumentError`, and a union discriminant without an arm throws `Exception`. Some of these envelopes previously decoded into a wrong transaction. `RangeError` and `ArgumentError` are not caught by `on Exception catch`
- SEP-7: a malformed `xdr` envelope is reported as invalid by `Sep7.isValidSep7Uri`, rejected with `Sep7InvalidUri` by `Sep7.parseSep7Uri` and `Sep7.addSignature`, and makes `Sep7.verifySignature` return false. When `stellar_flutter_sdk` throws an `Error` while decoding the envelope, the reason names it. In 1.1.5 some of these envelopes were accepted, such as a negative signatures count, a zero price denominator or a union discriminant without an arm, and others let a `RangeError` escape
- SEP-7: when SDK validation reports a URI as invalid, `Sep7.addSignature` throws `Sep7InvalidUri` with the validation reason; 1.1.5 threw `ArgumentError`. Malformed-envelope cases that previously escaped as `Error` or were accepted are described above
- SEP-7: `Sep7.isValidSep7Uri` reports a URI whose query is not valid percent-encoded UTF-8 as invalid, and `Sep7.parseSep7Uri` rejects it with `Sep7InvalidUri`; 1.1.5 threw `FormatException`
- the `price` of a manage offer or passive offer operation from `Stellar.decodeTransaction`, and the `minPrice` and `maxPrice` of a liquidity pool deposit, is the decimal expansion of the XDR fraction, truncated after 20 fraction digits and never in exponent notation: 1/10000000 reads `0.0000001` and 1/3 reads `0.33333333333333333333`. In 1.1.5 they read `1e-7` and `0.3333333333333333`, and a decoded transaction with a price in exponent notation could not be encoded again
- when the wallet signs or serializes offer and liquidity-pool-deposit operations, decimal prices are converted with exact integer arithmetic. For example, `0.99999999` encodes as `99999999/100000000`; in 1.1.5 it encoded as `1799999971/1799999989`. The accepted decimal syntax is unchanged; values at the int32 limits are evaluated at their exact decimal value
- SEP-10: a challenge that fails to decode is still reported as `AnchorAuthException`, with the new decoder message of `stellar_flutter_sdk`

## [1.1.5] - 15.Sep.2026.
- update to stellar_flutter_sdk 3.7.0
- a payment amount, path payment amount, trustline limit, or create-account starting balance outside the int64 stroop range (-922337203685.4775808 to 922337203685.4775807) now throws an `Exception` when the transaction is signed or serialized; such an amount previously went on the wire with only its low 64 bits kept (fixed in stellar_flutter_sdk)

## [1.1.4] - 25.Aug.2026.
- update to stellar_flutter_sdk 3.6.0, which supports Protocol 28 (Horizon v28.0.0)
- SEP-10: authentication now rejects challenge transactions whose first operation does not carry a 64-byte base64 encoding of a 48-byte nonce, and challenges without finite time bounds, as required by the spec (validated by stellar_flutter_sdk)
- SEP-6: the fee request sends the amount as a plain decimal; amounts below 1e-6 previously went out in exponential notation (fixed in stellar_flutter_sdk)

## [1.1.3] - 24.Jun.2026.
- update to stellar_flutter_sdk 3.2.0
- watcher: add the WatchCompleted event, emitted when the watched transaction(s) reach a terminal status (behavior change for watcher consumers)
- watcher: ExceptionHandlerExit now signals only that the retry handler gave up after repeated errors
- watcher: watchAsset no longer ends on an empty poll
- a configured ApplicationConfiguration.defaultClient is now also used for Horizon requests
- SEP-6: fix withdraw extraInfo and deposit maxAmount mapping; getTransactionBy now requires at least one identifier
- SEP-24: fix deposit asset lookup, which previously consulted the withdraw asset list
- SEP-38: fix price() not forwarding buyDeliveryMethod
- SEP-12: fix get() not forwarding lang
- SEP-7: parseSep7Uri now forwards the http client and request headers; unsupported operation types raise Sep7UriTypeNotSupported
- SEP-10: AuthToken now raises a ValidationException for a JWT missing the iss or sub claim instead of a raw type error
- AssetId.fromAsset now raises UnsupportedError for liquidity pool share assets
- TransactionStatus.fromString now maps the no_market status
- fix the TransactionSubmitFailedException message to separate the operation result codes
- path finding now surfaces request errors instead of returning an empty list
- loadRecentPayments and loadRecentTransactions now reject a non-positive limit
- add unit and integration test suites with CI and code coverage reporting

## [1.1.2] - 28.Apr.2026.
- update to stellar_flutter_sdk 3.0.5
- bump flutter_lints to 6.0
- clean up lib/ analyzer warnings (explicit return types, doc comments, logger usage)

## [1.1.1] - 10.Mar.2026.
- update to stellar_flutter_sdk 3.0.4
- SEP-24: make moreInfoUrl nullable
- SEP-30: make RecoverableIdentity role nullable

## [1.1.0] - 04.Feb.2026.
- add web platform support
- update to stellar_flutter_sdk 3.0.1

## [1.0.7] - 12.Sep.2025.
- update to use the new version 2.1.4 of the horizon flutter sdk

## [1.0.6] - 01.Sep.2025.
- update to use the new version 2.1.3 of the horizon flutter sdk

## [1.0.5] - 11.Aug.2025.
- update to use the new version 2.1.2 of the horizon flutter sdk

## [1.0.4] - 19.Jul.2025.
- update to use the new version 2.1.0 of the horizon flutter sdk (protocol 23 support)

## [1.0.3] - 26.Mai.2025.
- update to use the new version 2.0.0 of the horizon flutter sdk
- sep-7: allow null values for different parameters
- improve tests

## [1.0.2] - 26.Nov.2024.
- include the changes from 1.0.2-beta
- update to use the new version 1.9.1 of the horizon flutter sdk

## [1.0.2-beta] - 04.Nov.2024.
- support for protocol 22-rc3

## [1.0.1-beta] - 29.Oct.2024.
- prepare for protocol 22 upgrade

## [1.0.0] - 06.Oct.2024.
- add sep-7 support
- update to use the new version 1.8.8 of the base flutter sdk

## [0.3.6] - 18.Sep.2024.
- extend transaction building by adding: accountMerge, pathPay and swap
- extend stellar, add fundTestNetAccount
- update to use the new version 1.8.7 of the base flutter sdk

## [0.3.5] - 19.Aug.2024.
- update to use the new version 1.8.6 of the core flutter sdk
- SEP-06: allow extra fields to be added in the deposit and withdrawal requests.
- SEP-06: add the new userActionRequired field to the transaction response object.
- SEP-06: add fee endpoint.
- SEP-24: add the new userActionRequired field to the transaction response object.
- SEP-12: null safety improvements.

## [0.3.4] - 25.July.2024.
- update to use the new version 1.8.4 of the core flutter sdk
- extend sep-12 support: get customer information by different parameters

## [0.3.3] - 16.July.2024.
- update to use the new version 1.8.3 of the core flutter sdk

## [0.3.2] - 1.July.2024.
- update to use the new version 1.8.2 of the core flutter sdk
- add account service utility methods loadRecentPayments and loadRecentTransactions

## [0.3.1] - 14.June.2024.
- add support for path payments

## [0.3.0] - 24.Apr.2024.
- add programmatic deposit and withdrawal (sep-6)

## [0.2.0] - 02.Feb.2024.
- add quotes service (sep-38)

## [0.1.0] - 17.Jan.2024.
- add stellar functionality for typical wallet flows
- extend examples
- extend tests
- extend docs

## [0.0.3] - 21.Dec.2023.
- add recovery service (sep-30)

## [0.0.2] - 30.Oct.2023.
- add full example app with sep-24 example
- allow null amount values for sep-24 transaction amounts

## [0.0.1] - 31.Aug.2023.
- anchor handling
