Feature: Display system error
  In order to be able to repair the project config
  As a project maintainer
  I want to see errors that can't be mailed to me on the start page

  Scenario: Config read failure
    Given the config read failed
    When I go to the start page
    Then I should see "project's last system error"
