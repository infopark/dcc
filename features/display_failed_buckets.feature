Feature: Display failed buckets
  In order to be able to find the failed buckets faster
  As a project maintainer
  I want to see the failed buckets on the project page

  Scenario: Some buckets failed
    Given a project has failed buckets
    When I go to the project page
    Then I should see the failed buckets
    But I should not see the buckets that not failed
    And I should be able to reach the bucket pages of the failed buckets
