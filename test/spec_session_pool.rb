# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require_relative 'helper'

require 'rack/response'
require 'rack/mock'
require 'rack/utils'
require 'rack/lint'

require_relative '../lib/rack/session/pool'

describe Rack::Session::Pool do
  session_key = Rack::Session::Pool::DEFAULT_OPTIONS[:key]
  session_match = /#{session_key}=([0-9a-fA-F]+);/

  incrementor = lambda do |env|
    env["rack.session"]["counter"] ||= 0
    env["rack.session"]["counter"] += 1
    Rack::Response.new(env["rack.session"].inspect).to_a
  end

  get_session_id = Rack::Lint.new(lambda do |env|
    Rack::Response.new(env["rack.session"].inspect).to_a
  end)

  nothing = Rack::Lint.new(lambda do |env|
    Rack::Response.new("Nothing").to_a
  end)

  drop_session = Rack::Lint.new(lambda do |env|
    env['rack.session.options'][:drop] = true
    incrementor.call(env)
  end)

  renew_session = Rack::Lint.new(lambda do |env|
    env['rack.session.options'][:renew] = true
    incrementor.call(env)
  end)

  defer_session = Rack::Lint.new(lambda do |env|
    env['rack.session.options'][:defer] = true
    incrementor.call(env)
  end)

  incrementor = Rack::Lint.new(incrementor)

  it "creates a new cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).get("/")
    res["Set-Cookie"].must_match(session_match)
    res.body.must_equal ({"counter"=>1}.to_s)
  end

  it "determines session from a cookie" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    cookie = req.get("/")["Set-Cookie"]
    req.get("/", "HTTP_COOKIE" => cookie).
      body.must_equal ({"counter"=>2}.to_s)
    req.get("/", "HTTP_COOKIE" => cookie).
      body.must_equal ({"counter"=>3}.to_s)
  end

  it "survives nonexistent cookies" do
    pool = Rack::Session::Pool.new(incrementor)
    res = Rack::MockRequest.new(pool).
      get("/", "HTTP_COOKIE" => "#{session_key}=blarghfasel")
    res.body.must_equal ({"counter"=>1}.to_s)
  end

  it "does not send the same session id if it did not change" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res0 = req.get("/")
    cookie = res0["Set-Cookie"][session_match]
    res0.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 1

    res1 = req.get("/", "HTTP_COOKIE" => cookie)
    res1["Set-Cookie"].must_be_nil
    res1.body.must_equal ({"counter"=>2}.to_s)
    pool.pool.size.must_equal 1

    res2 = req.get("/", "HTTP_COOKIE" => cookie)
    res2["Set-Cookie"].must_be_nil
    res2.body.must_equal ({"counter"=>3}.to_s)
    pool.pool.size.must_equal 1
  end

  it "deletes cookies with :drop option" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    drop = Rack::Utils::Context.new(pool, drop_session)
    dreq = Rack::MockRequest.new(drop)

    res1 = req.get("/")
    session = (cookie = res1["Set-Cookie"])[session_match]
    res1.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 1

    res2 = dreq.get("/", "HTTP_COOKIE" => cookie)
    res2["Set-Cookie"].must_be_nil
    res2.body.must_equal ({"counter"=>2}.to_s)
    pool.pool.size.must_equal 0

    res3 = req.get("/", "HTTP_COOKIE" => cookie)
    res3["Set-Cookie"][session_match].wont_equal session
    res3.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 1
  end

  it "provides new session id with :renew option" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    renew = Rack::Utils::Context.new(pool, renew_session)
    rreq = Rack::MockRequest.new(renew)

    res1 = req.get("/")
    session = (cookie = res1["Set-Cookie"])[session_match]
    res1.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 1

    res2 = rreq.get("/", "HTTP_COOKIE" => cookie)
    new_cookie = res2["Set-Cookie"]
    new_session = new_cookie[session_match]
    new_session.wont_equal session
    res2.body.must_equal ({"counter"=>2}.to_s)
    pool.pool.size.must_equal 1

    res3 = req.get("/", "HTTP_COOKIE" => new_cookie)
    res3.body.must_equal ({"counter"=>3}.to_s)
    pool.pool.size.must_equal 1

    res4 = req.get("/", "HTTP_COOKIE" => cookie)
    res4.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 2
  end

  it "omits cookie with :defer option" do
    pool = Rack::Session::Pool.new(incrementor)
    defer = Rack::Utils::Context.new(pool, defer_session)
    dreq = Rack::MockRequest.new(defer)

    res1 = dreq.get("/")
    res1["Set-Cookie"].must_be_nil
    res1.body.must_equal ({"counter"=>1}.to_s)
    pool.pool.size.must_equal 1
  end

  it "can read the session with the legacy id" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res0 = req.get("/")
    cookie = res0["Set-Cookie"]
    session_id = Rack::Session::SessionId.new cookie[session_match, 1]
    ses0 = pool.pool[session_id.private_id]
    pool.pool[session_id.public_id] = ses0
    pool.pool.delete(session_id.private_id)

    res1 = req.get("/", "HTTP_COOKIE" => cookie)
    res1["Set-Cookie"].must_be_nil
    res1.body.must_equal(({"counter"=>2}.to_s))
    pool.pool[session_id.private_id].wont_be_nil
  end

  it "cannot read the session with the legacy id if allow_fallback: false option is used" do
    pool = Rack::Session::Pool.new(incrementor, allow_fallback: false)
    req = Rack::MockRequest.new(pool)

    res0 = req.get("/")
    cookie = res0["Set-Cookie"]
    session_id = Rack::Session::SessionId.new cookie[session_match, 1]
    ses0 = pool.pool[session_id.private_id]
    pool.pool[session_id.public_id] = ses0
    pool.pool.delete(session_id.private_id)

    res1 = req.get("/", "HTTP_COOKIE" => cookie)
    res1["Set-Cookie"].wont_be_nil
    res1.body.must_equal ({"counter"=>1}.to_s)
  end

  it "drops the session in the legacy id as well" do
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)
    drop = Rack::Utils::Context.new(pool, drop_session)
    dreq = Rack::MockRequest.new(drop)

    res0 = req.get("/")
    cookie = res0["Set-Cookie"]
    session_id = Rack::Session::SessionId.new cookie[session_match, 1]
    ses0 = pool.pool[session_id.private_id]
    pool.pool[session_id.public_id] = ses0
    pool.pool.delete(session_id.private_id)

    res2 = dreq.get("/", "HTTP_COOKIE" => cookie)
    res2["Set-Cookie"].must_be_nil
    res2.body.must_equal ({"counter"=>2}.to_s)
    pool.pool[session_id.private_id].must_be_nil
    pool.pool[session_id.public_id].must_be_nil
  end

  it "passes through same_site option to session pool" do
    pool = Rack::Session::Pool.new(incrementor, same_site: :none)
    pool.same_site.must_equal :none
    req = Rack::MockRequest.new(pool)
    res = req.get("/")
    res["Set-Cookie"].must_match /SameSite=None/i
  end

  it "allows using a lambda to specify same_site option, because some browsers require different settings" do
    pool = Rack::Session::Pool.new(incrementor, same_site: lambda { |req, res| :none })
    req = Rack::MockRequest.new(pool)
    res = req.get("/")
    res["Set-Cookie"].must_match /SameSite=None/i

    pool = Rack::Session::Pool.new(incrementor, same_site: lambda { |req, res| :lax })
    req = Rack::MockRequest.new(pool)
    res = req.get("/")
    res["Set-Cookie"].must_match /SameSite=Lax/i
  end

  # anyone know how to do this better?
  it "should merge sessions when multithreaded" do
    unless $DEBUG
      1.must_equal 1
      next
    end

    warn 'Running multithread tests for Session::Pool'
    pool = Rack::Session::Pool.new(incrementor)
    req = Rack::MockRequest.new(pool)

    res = req.get('/')
    res.body.must_equal ({"counter"=>1}.to_s)
    cookie = res["Set-Cookie"]
    sess_id = cookie[/#{pool.key}=([^,;]+)/, 1]

    delta_incrementor = lambda do |env|
      # emulate disconjoinment of threading
      env['rack.session'] = env['rack.session'].dup
      Thread.stop
      env['rack.session'][(Time.now.usec * rand).to_i] = true
      incrementor.call(env)
    end
    tses = Rack::Utils::Context.new pool, delta_incrementor
    treq = Rack::MockRequest.new(tses)
    tnum = rand(7).to_i + 5
    r = Array.new(tnum) do
      Thread.new(treq) do |run|
        run.get('/', "HTTP_COOKIE" => cookie)
      end
    end.reverse.map{|t| t.run.join.value }
    r.each do |resp|
      resp['Set-Cookie'].must_equal cookie
      resp.body.must_include '"counter"=>2'
    end

    session = pool.pool[sess_id]
    session.size.must_equal tnum + 1 # counter
    session['counter'].must_equal 2 # meeeh
  end

  it "does not return a cookie if cookie was not read/written" do
    app = Rack::Session::Pool.new(nothing)
    res = Rack::MockRequest.new(app).get("/")
    res["Set-Cookie"].must_be_nil
  end

  it "does not return a cookie if cookie was not written (only read)" do
    app = Rack::Session::Pool.new(get_session_id)
    res = Rack::MockRequest.new(app).get("/")
    res["Set-Cookie"].must_be_nil
  end

  it "returns even if not read/written if :expire_after is set" do
    app = Rack::Session::Pool.new(nothing, expire_after: 3600)
    res = Rack::MockRequest.new(app).get("/", 'rack.session' => { 'not' => 'empty' })
    res["Set-Cookie"].wont_be :nil?
  end

  it "returns no cookie if no data was written and no session was created previously, even if :expire_after is set" do
    app = Rack::Session::Pool.new(nothing, expire_after: 3600)
    res = Rack::MockRequest.new(app).get("/")
    res["Set-Cookie"].must_be_nil
  end

  user_id_session = Rack::Lint.new(lambda do |env|
    session = env["rack.session"]

    case env["PATH_INFO"]
    when "/login"
      session[:user_id] = 1
    when "/logout"
      if session[:user_id].nil?
        raise "User not logged in"
      end

      session.delete(:user_id)
      session.options[:renew] = true
    when "/slow"
      Fiber.yield
    end

    Rack::Response.new(session.inspect).to_a
  end)

  it "doesn't allow session id to be reused" do
    app = Rack::Session::Pool.new(user_id_session)

    login_response = Rack::MockRequest.new(app).get("/login")
    login_cookie = login_response["Set-Cookie"]

    slow_request = Fiber.new do
      Rack::MockRequest.new(app).get("/slow", "HTTP_COOKIE" => login_cookie)
    end
    slow_request.resume

    # Check that the session is valid:
    response = Rack::MockRequest.new(app).get("/", "HTTP_COOKIE" => login_cookie)
    response.body.must_equal({"user_id" => 1}.to_s)

    logout_response = Rack::MockRequest.new(app).get("/logout", "HTTP_COOKIE" => login_cookie)
    logout_cookie = logout_response["Set-Cookie"]

    # Check that the session id is different after logout:
    login_cookie[session_match].wont_equal logout_cookie[session_match]

    slow_response = slow_request.resume

    # Check that the cookie can't be reused:
    response = Rack::MockRequest.new(app).get("/", "HTTP_COOKIE" => login_cookie)
    response.body.must_equal "{}"
  end
end
