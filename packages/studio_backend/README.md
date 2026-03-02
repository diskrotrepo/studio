# diskrot Studio Backend


## Running Locally

You run locally with by running the following command: `dart run bin/server.dart`


# Local Development

## Adding new routes

You must add the `part` to the class and then run `dart run build_runner build --delete-conflicting-outputs` for an example see `lib/client/client_service.dart`

## Adding new DTO

You must add the `part` to the class and then run `dart run build_runner build --delete-conflicting-outputs` for an example see `lib/authentication/authentication_dto.dart`

## Database Upgrades

```bash
sh database_builder.sh
```