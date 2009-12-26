Feature: Display bucket duration
  In order to get information about a bucket's progress
  As a project maintainer
  I want to see the duration of a bucket processing

  Scenario: Bucket is currently being processed
    Given there is a bucket under process
    When I go to it's bucket page
    Then I should see it's start time
    And I should not see it's duration

  Scenario: Bucket is finished
    Given there is a finished bucket
    When I go to it's bucket page
    Then I should see it's duration
    And I should not see it's start time

  Scenario: Bucket not yet processed
    Given there is an unprocessed bucket
    When I go to it's bucket page
    Then I should not see it's start time
    And I should not see it's duration

