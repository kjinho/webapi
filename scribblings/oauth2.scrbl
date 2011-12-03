#lang scribble/doc
@(require scribble/manual
          scribble/eval
          scribble/struct
          racket/sandbox
          "config.rkt"
          (for-label (this-package-in oauth2)))

@title[#:tag "oauth2"]{OAuth 2.0 Client}

@(defmodule/this-package oauth2)

This library is an incomplete implementation of an unfinished
standard; use with care. It is certain to evolve as features are added
and as the standard solidifies.

This library supports a subset of the OAuth 2.0 authorization
protocol. The OAuth 2.0 specification is currently in draft state;
this library is based on
@hyperlink["http://tools.ietf.org/html/draft-ietf-oauth-v2-22"]{draft
22} (released 22-Sep-2011, expires 25-Mar-2011). The implementation is
currently designed to work with the requirements of the
@hyperlink["http://code.google.com/apis/accounts/docs/OAuth2.html"]{Google
authorization server} (as of 17-Nov-2011); it may not work yet in other
contexts.

@section{OAuth 2.0 Overview}

The protocol involves four parties: @emph{resource owner},
@emph{resource server(s)}, @emph{client}, and @emph{authorization
server}. This library may be used by clients to talk to resource
servers and authorization servers; it provides no support for
implementors of resource servers or authorization servers.

An OAuth 2.0 interaction is represented by an object implementing the
@racket[oauth2<%>] interface. It consists of a client, an
authorization server, the access ``scopes'' granted, and any tokens
issued by the authorization server. Clients are represented by objects
implementing @racket[oauth2-client<%>], and authorization servers are
represented by objects implementing
@racket[oauth2-auth-server<%>]. Scopes and tokens are represented as
strings.

A client (@racket[oauth2-client<%>]) contains a client ID and
optionally a client secret, both obtained by registering a client
application with an authorization server. The client object represents
only the ID and credentials of a registered client, not its
behavior.

An authorization server (@racket[oauth2-auth-server<%>]) contains the
URLs used to serve client authorization requests. These URLs have
nothing to do with the URLs used to access protected resources.

Resource servers are not represented directly in this library;
instead, a client program makes HTTP requests directly to a resource
server including HTTP headers generated by a @racket[oauth2<%>]
object. Currently only bearer tokens are supported; see
@secref["oauth2-security"].

The following subsections outline the support for various usage
scenarios.

@subsection{OAuth 2.0 for Native Applications}

This scenario applies to clients that are Racket programs running on
the resource owner's machine. Since the client is under the control of
the resource owner, its credentials, including the ``client secret,''
should @emph{not} be considered secret.

A native application can obtain an @racket[oauth2<%>] object in the
following ways:
@itemlist[
@item{Use @racket[oauth2/request-auth-code/browser] to open a web browser with
  an @emph{authorization code} request to the authorization server. If
  the request is granted, the browser is redirected to a
  @tt{localhost} URL, where a web server created specifically for the
  request acquires the authorization code, uses it to create the
  @racket[oauth2<%>] object, and shuts down.}
@item{Use @method[oauth2-auth-server<%> get-auth-request-url] to
  generate an authorization request URL. The user must visit the URL,
  grant access, and call @racket[oauth2/auth-code] with the resulting
  authorization code. Use this process when either automatically
  opening a web browser or starting a local web server is not
  desirable.}
@item{Use @racket[oauth2/refresh-token] with a long-lived ``refresh
  token'' obtained from an earlier authorization grant. (See
  @method[oauth2<%> get-refresh-token].)}
]
A client program may wish to use @racket[oauth2/request-auth-code/browser]
for the initial request and then store the refresh code for future
runs of the program. Or the client program may just use
@racket[oauth2/request-auth-code/browser] at the beginning of each run, if
it has no access to reasonably secure persistent storage.

@subsection{OAuth 2.0 for User-Agent-Based Applications}

Not applicable. In practice, this scenario applies only to Javascript
clients running in a web browser (``user agent'').

@subsection{OAuth 2.0 for Web Applications}

This scenario applies to clients that are web applications running on
a server not under the resource owner's control. In contrast to the
``native application'' scenario, the client may keep secrets, such as
its credentials, from the resource owner.

A web application can obtain an @racket[oauth2<%>] object in the
following ways:
@itemlist[
@item{Forward the user to the URL generated by
  @method[oauth2-auth-server<%> get-auth-request-url]; use the
  @racket[_state] argument to represent the current
  session/context. After granting authorization, the user will be
  redirected to the @racket[_redirect-uri] with the authorization code
  and user state in the @tt{code} and @tt{state} query arguments,
  respectively. Call @racket[oauth2/auth-code] with the authorization
  code.}
@item{Use @racket[oauth2/refresh-token] with a long-lived ``refresh
  token'' obtained from an earlier authorization grant. (See
  @method[oauth2<%> get-refresh-token].)}
]

@section{OAuth 2.0 Reference}

@definterface[oauth2-auth-server<%> ()]{

Represents an authorization server. Obtain an instance via
@racket[oauth2-auth-server], or use the @racket[google-auth-server]
instance.

@defmethod[(get-auth-url) string?]{
  Returns the base URL for authorization requests presented to the
  resource owner, generally used to obtain authorization codes.

@examples[#:eval the-eval
(send google-auth-server get-auth-url)
]
}
@defmethod[(get-token-url) string?]{
  Returns the base URL for token requests made automatically by the
  client.

@examples[#:eval the-eval
(send google-auth-server get-token-url)
]
}
@defmethod[(get-auth-request-url
             [#:client client (is-a?/c oauth2-client<%>)]
             [#:scopes scopes (listof string?)]
             [#:redirect-uri redirect-uri string? "urn:ietf:wg:oauth:2.0:oob"]
             [#:state state (or/c string? #f) #f])
           string?]{

  Returns a URL (as a string) that can be visited in a browser to
  request authorization for @racket[client] to access resources in the
  given @racket[scopes]. 

  The default @racket[redirect-uri] is a special URI indicating that
  the authorization server should redirect to a page of its own
  displaying the authorization code, rather than sending it via
  redirection to a page under the client's control.
}
}

@defproc[(oauth2-auth-server [#:auth-url auth-url string?]
                             [#:token-url token-url string?])
         (is-a?/c oauth2-auth-server<%>)]{

  Creates an @racket[oauth2-auth-server<%>] representation, given its
  endpoint URLs.
}

@defthing[google-auth-server (is-a?/c oauth2-auth-server<%>)]{

  Represents the authorization server for
  @hyperlink["http://code.google.com/apis/accounts/docs/OAuth2.html"]{Google
  APIs}.
}

@;{------------------------------------------------------------}

@definterface[oauth2-client<%> ()]{

Represents a client registered with some authorization
server. Obtain an instance via @racket[oauth2-client].

@defmethod[(get-id) string?]{
  Returns the client's ID string.
}
@defmethod[(get-secret) (or/c string? #f)]{
  Returns the client's secret.
}
}

@defproc[(oauth2-client [#:id id string?]
                        [#:secret secret (or/c string? #f) #f])
         (is-a?/c oauth2-client<%>)]{

  Creates a client object with ID @racket[id] and secret
  @racket[secret].
}

@;{------------------------------------------------------------}

@definterface[oauth2<%> ()]{

Represents a client with authorizations for some set of resources.

Obtain an instance via @racket[oauth2/request-auth-code/browser],
@racket[oauth2/auth-code], or @racket[oauth2/refresh-token].

@defmethod[(get-client-id) string?]{
  Returns the client ID string.
}
@defmethod[(get-access-token [#:re-acquire? re-acquire? #t])
           (or/c string? #f)]{

  Returns the current access token, if one is available and has not
  expired.

  If there is no current access token and @racket[re-acquire?] is
  @racket[#f], the method returns @racket[#f]. Otherwise, if there is
  no current access token and @racket[re-acquire?] is true, the object
  attempts to acquire a new access token---such as by using a
  long-lived refresh token, if one was provided by the authorization
  server.
}
@defmethod[(get-refresh-token)
           (or/c string? #f)]{

  Returns the refresh token, if one was provided by the authorization
  server, @racket[#f] otherwise.
}
@defmethod[(headers)
           (listof string?)]{

  Returns a list of HTTP headers to be used in HTTP requests to
  resource servers. Currently only bearer tokens are supported; see
  @secref["oauth2-security"].
}
}

@defproc[(oauth2/auth-code [auth-server (is-a?/c oauth2-auth-server<%>)]
                           [client (is-a?/c oauth2-client<%>)]
                           [auth-code string?]
                           [#:redirect-uri redirect-uri string? "urn:ietf:wg:oauth:2.0:oob"])
         (is-a?/c oauth2<%>)]{

  Creates an @racket[oauth2<%>] object, using the given
  @racket[auth-code] to request an access token from
  @racket[auth-server]; a refresh token may or may not be granted as
  well. The @racket[redirect-uri] argument must match the redirection
  URI used to request the authorization code.
}

@defproc[(oauth2/refresh-token [auth-server (is-a?/c oauth2-auth-server<%>)]
                               [client (is-a?/c oauth2-client<%>)]
                               [refresh-token string?])
         (is-a?/c oauth2<%>)]{

  Creates an @racket[oauth2<%>] object, using a previously granted
  (long-lived) @racket[refresh-token] to acquire a new short-lived
  access token.
}

@defproc[(oauth2/request-auth-code/browser
             [auth-server (is-a?/c oauth2-auth-server<%>)]
             [client (is-a?/c oauth2-client<%>)]
             [scopes (listof string?)])
         (is-a?/c oauth2<%>)]{

  Automates the combination of @method[oauth2-auth-server<%>
  get-auth-request-url] and @racket[oauth2/auth-code] by opening a
  browser window and creating an ad hoc web server running on
  @tt{localhost:8000} and supplying a redirection URL of
  @racket["http://localhost:8000/oauth2/response"] in the
  authorization code request to @racket[auth-server].
}

@section[#:tag "oauth2-security"]{OAuth 2.0 Security Notes}

This library currently only supports
@hyperlink["http://tools.ietf.org/html/draft-ietf-oauth-v2-bearer"]{bearer
access tokens}, because the Google authorization server only issues
bearer tokens. A bearer token is used by directly including in an
``Authorization'' HTTP header; consequently, any request that uses a
bearer token must use transport-level security such as SSL/TLS.
