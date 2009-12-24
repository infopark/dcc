include Webrat::HaveTagMatcher

Given /^a project has failed buckets$/ do
  @project_id = 4
end

Then /^I should see the failed buckets$/ do
  %w(failed:one failed:two).each do |name|
    if defined?(Spec::Rails::Matchers)
      response.should contain(name)
    else
      assert_contain name
    end
  end
end

Then /^I should not see the buckets that not failed$/ do
  %w(succeeded:one pending:one in_work:one).each do |name|
    if defined?(Spec::Rails::Matchers)
      response.should_not contain(name)
    else
      assert_not_contain name
    end
  end
end

Then /^I should be able to reach the bucket pages of the failed buckets$/ do
  [411, 412].each do |id|
    assert_have_tag("a[href='/project/show_bucket/#{id}']")
  end
end

