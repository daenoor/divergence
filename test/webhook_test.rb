require 'test_helper'

class WebhookTest < Test::Unit::TestCase
  def test_detect
    force_branch :master
    status, _, body = mock_webhook :master

    assert_equal 200, status
    assert_equal ["OK"], body
  end

  def test_ignore
    force_branch :master
    status, _, body = mock_webhook :branch1

    assert_equal 200, status
    assert_equal ["IGNORE"], body
  end
end