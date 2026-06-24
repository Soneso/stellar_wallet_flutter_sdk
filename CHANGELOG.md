## [1.1.3] - 22.Jun.2026.
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
