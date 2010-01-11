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

Given /^there is a (build|bucket) under process$/ do |dummy|
  @bucket_id = 415
  @build_id = 41
end

Then /^I should (not )?see the (build|bucket)'s start time$/ do |should_not, type|
  if should_not
    response.should_not contain("since")
  else
    response.should contain("since 2006-08-30 0#{type == 'build' ? '0:1' : '7:4'}5")
  end
end

Then /^I should (not )?see the (build|bucket)'s duration$/ do |should_not, type|
  if should_not
    response.should_not contain("\<in\>")
  else
    response.should contain("in 1 hour #{type == 'build' ? '13' : '38'} minutes 46 seconds")
  end
end

Given /^there is a finished (build|bucket)$/ do |dummy|
  @bucket_id = 413
  @build_id = 42
end

Given /^there is an unprocessed (build|bucket)$/ do |dummy|
  @bucket_id = 414
  @build_id = 43
end

