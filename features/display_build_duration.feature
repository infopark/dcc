Feature: Display build duration
  In order to get information about a build's progress
  As a project maintainer
  I want to see the duration of a build processing

  Scenario: Build is currently being processed
    Given there is a build under process
    When I go to it's build page
    Then I should see the build's start time
    And I should not see the build's duration

  Scenario: Build is finished
    Given there is a finished build
    When I go to it's build page
    Then I should see the build's duration
    And I should not see the build's start time

  Scenario: Build not yet processed
    Given there is an unprocessed build
    When I go to it's build page
    Then I should not see the build's start time
    And I should not see the build's duration
