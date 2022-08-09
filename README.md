# Rack::Session

Session management implementation for Rack.

[![Development Status](https://github.com/rack/rack-session/workflows/Development/badge.svg)](https://github.com/rack/rack-session/actions?workflow=Development)

## Usage

In your `config.ru`:

```ruby
# config.ru

use Rack::Session::Cookie,
  :domain => 'mywebsite.com',
  :path => '/',
  :expire_after => 3600*24,
  :secret => '**unique secret key**'
```

Usage follows the standard outlined by `rack.session`, i.e.:

```ruby
class MyApp
  def call(env)
    session = env['rack.session']

    # Set some state:
    session[:key] = "value"
  end
end
```

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

## License

Released under the MIT license.

Copyright, 2021, by [Samuel G. D. Williams](https://www.codeotaku.com).  
Copyright, 2020, by [Michael Coyne](https://michaeljcoyne.me/).  
Copyright, 2007-2021, by [Leah Neukirchen](https://leahneukirchen.org).  

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
