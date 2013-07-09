require 'test/unit'
require File.join(File.dirname(__FILE__), '..', '/lib/google_plus_archiver.rb')

class TestGooglePlusArchiver < Test::Unit::TestCase
  def test_get_full_image_url
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh4.googleusercontent.com/-p34gf3QVFw8/UTiqnTcGEGI/AAAAAAAA0Eg/_MPT34wVCYU/s288/photo.jpg'), 'https://lh4.googleusercontent.com/-p34gf3QVFw8/UTiqnTcGEGI/AAAAAAAA0Eg/_MPT34wVCYU/s0-d/photo.jpg'
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh6.googleusercontent.com/-LD9x9FXtIpk/UduHh3OXgnI/AAAAAAAQPJw/4Y6DJjCieBA/w337-h337-p/photo.jpg'), 'https://lh6.googleusercontent.com/-LD9x9FXtIpk/UduHh3OXgnI/AAAAAAAQPJw/4Y6DJjCieBA/s0-d/photo.jpg'
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh4.googleusercontent.com/-0pCnCqfbR88/URyOsOnfaRI/AAAAAAAAMDA/fC9xc2ZJiFg/w506-h750/1CE7AF9B-6E96-4BF5-A260-805F1E9B5671.JPG'), 'https://lh4.googleusercontent.com/-0pCnCqfbR88/URyOsOnfaRI/AAAAAAAAMDA/fC9xc2ZJiFg/s0-d/1CE7AF9B-6E96-4BF5-A260-805F1E9B5671.JPG'
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh4.googleusercontent.com/-aULSQOCqUrU/UdljOe8521I/AAAAAAAAPuw/OZtgtnhHm6s/photo.jpg'), 'https://lh4.googleusercontent.com/-aULSQOCqUrU/UdljOe8521I/AAAAAAAAPuw/OZtgtnhHm6s/s0-d/photo.jpg'
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh6.googleusercontent.com/proxy/xe5fwya_RD1B3HHk-Iq1qTAHw7cs6DsgpXOnNZC6YXpaIotggsKBR5x4hA2lAYpRETuU3_-z7pURPeyw0ig=w125-h125'), 'https://lh6.googleusercontent.com/proxy/xe5fwya_RD1B3HHk-Iq1qTAHw7cs6DsgpXOnNZC6YXpaIotggsKBR5x4hA2lAYpRETuU3_-z7pURPeyw0ig=w125-h125'
    assert_equal GooglePlusArchiver::get_full_image_url('https://lh4.googleusercontent.com/-kT9-9Tu1sxw/AAAAAAAAAAI/AAAAAAAAAC0/iXzWroHnvCY/photo.jpg?sz=50'), 'https://lh4.googleusercontent.com/-kT9-9Tu1sxw/AAAAAAAAAAI/AAAAAAAAAC0/iXzWroHnvCY/photo.jpg?sz=50'
    assert_equal GooglePlusArchiver::get_full_image_url('http://www.camlcity.org/files/img/ofcourse.png'), 'http://www.camlcity.org/files/img/ofcourse.png'
    
  end
  
end
