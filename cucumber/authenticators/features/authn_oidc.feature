Feature: Users can authneticate with OIDC authenticator

  Background:
    Given a policy:
    """
    - !policy
      id: conjur/authn-oidc/keycloak
      body:
      - !webservice
        annotations:
          description: Authentication service for Keycloak, based on Open ID Connect.

      - !variable
        id: provider-uri

      - !variable
        id: id-token-user-property

      - !group users

      - !permit
        role: !group users
        privilege: [ read, authenticate ]
        resource: !webservice

    - !user alice

    - !grant
      role: !group conjur/authn-oidc/keycloak/users
      member: !user alice
    """
    And I am the super-user
    And I successfully set OIDC variables

  Scenario: A valid id token to get Conjur access token
    # We want to verify the returned access token is valid for retrieving a secret
    Given I have a "variable" resource called "test-variable"
    And I permit user "alice" to "execute" it
    And I add the secret value "test-secret" to the resource "cucumber:variable:test-variable"
    And I get authorization code for username "alice" and password "alice"
    And I fetch an ID Token
    When I authenticate via OIDC with id token
    Then user "alice" is authorized
    And I successfully GET "/secrets/cucumber/variable/test-variable" with authorized user

  Scenario: A valid id token with email as id-token-user-property
    Given I extend the policy with:
    """
    - !user alice@conjur.net

    - !grant
      role: !group conjur/authn-oidc/keycloak/users
      member: !user alice@conjur.net
    """
    When I add the secret value "email" to the resource "cucumber:variable:conjur/authn-oidc/keycloak/id-token-user-property"
    And I get authorization code for username "alice" and password "alice"
    And I fetch an ID Token
    And I authenticate via OIDC with id token
    Then user "alice@conjur.net" is authorized

  Scenario: Adding a group to keycloak/users group permits users to authenticate
    Given I extend the policy with:
    """
    - !user bob

    - !group more-users

    - !grant
      role: !group more-users
      member: !user bob

    - !grant
      role: !group conjur/authn-oidc/keycloak/users
      member: !group more-users
    """
    And I get authorization code for username "bob" and password "bob"
    And I fetch an ID Token
    When I authenticate via OIDC with id token
    Then user "bob" is authorized

  Scenario: Non-existing username in ID token is denied
    Given I get authorization code for username "not_in_conjur" and password "not_in_conjur"
    And I fetch an ID Token
    And I save my place in the log file
    When I authenticate via OIDC with id token
    Then it is unauthorized
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::Security::UserNotDefinedInConjur
    """

  Scenario: User that is not permitted to webservice in ID token is denied
    Given I extend the policy with:
    """
    - !user bob
    """
    And I get authorization code for username "bob" and password "bob"
    And I fetch an ID Token
    And I save my place in the log file
    When I authenticate via OIDC with id token
    Then it is unauthorized
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::Security::UserNotAuthorizedInConjur
    """

  Scenario: ID token without value of variable id-token-user-property is denied
    When I add the secret value "non_existing_field" to the resource "cucumber:variable:conjur/authn-oidc/keycloak/id-token-user-property"
    And I get authorization code for username "alice" and password "alice"
    And I fetch an ID Token
    And I save my place in the log file
    When I authenticate via OIDC with id token
    Then it is unauthorized
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::AuthnOidc::IdTokenFieldNotFoundOrEmpty
    """

  Scenario: Missing id token is a bad request
    Given I save my place in the log file
    When I authenticate via OIDC with no id token
    Then it is a bad request
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::RequestBody::MissingRequestParam
    """

  Scenario: Empty id token is a bad request
    Given I save my place in the log file
    When I authenticate via OIDC with empty id token
    Then it is a bad request
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::RequestBody::MissingRequestParam
    """

  # Should be crashed in GA, update the message to "account does not exists"
  Scenario: non-existing account in request is denied
    Given I get authorization code for username "alice" and password "alice"
    And I fetch an ID Token
    And I save my place in the log file
    When I authenticate via OIDC with id token and account "non-existing"
    Then it is unauthorized
    And The following appears in the log after my savepoint:
    """
    Errors::Conjur::RequiredResourceMissing
    """

  Scenario: admin user is denied
    Given I get authorization code for username "admin" and password "admin"
    And I fetch an ID Token
    And I save my place in the log file
    When I authenticate via OIDC with id token
    Then it is unauthorized
    And The following appears in the log after my savepoint:
    """
    Errors::Authentication::AuthnOidc::AdminAuthenticationDenied
    """
