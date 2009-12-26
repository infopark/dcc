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

Given /^there is a bucket under process$/ do
  @bucket_id = 415
end

Then /^I should (not )?see it's start time$/ do |should_not|
  if should_not
    response.should_not contain("since")
  else
    response.should contain("since 2006-08-30 07:45")
  end
end

Then /^I should (not )?see it's duration$/ do |should_not|
  if should_not
    response.should_not contain("\<in\>")
  else
    response.should contain("in 1 hour 38 minutes 46 seconds")
  end
end

Given /^there is a finished bucket$/ do
  @bucket_id = 413
end

Given /^there is an unprocessed bucket$/ do
  @bucket_id = 414
end

