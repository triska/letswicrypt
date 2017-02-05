# LetSWICrypt &mdash; HTTPS servers with SWI-Prolog

SWI-Prolog is extremely well suited for writing
[**web&nbsp;applications**](https://www.metalevel.at/prolog/web).

This repository shows you how to set up and run a secure&nbsp;(HTTPS)
web&nbsp;server using SWI-Prolog and *Let's&nbsp;Encrypt* and other
certificate authorities.

# Requirements

SWI-Prolog <b>7.3.21</b> or later ships with everything that is
necessary to run HTTPS&nbsp;servers as described in the following.

# Obtaining a certificate

For the sake of concreteness, assume that we want to set up an
HTTPS&nbsp;server that is reachable at `xyz.com` and
`www.xyz.com`. These names are chosen also because they are easy to
search for and do not occur anywhere else in the configuration files.

## Variant A: Use *Let's Encrypt*

[**Let's Encrypt**](https://letsencrypt.org/) is a free certificate
authority&nbsp;(CA).

The tool is easy to install and run. Follow the instructions on their
page, and then execute the following command on the host machine:

    $ sudo certbot certonly --standalone -d xyz.com -d www.xyz.com

**Note**: This requires that you *stop* any server that listens on
port&nbsp;80 or port&nbsp;443, until the certificate is obtained. There
are also other ways to obtain a certificate that allow you to keep
existing servers running. See below for more information.

After this is completed, you obtain 4 files in `/etc/letsencrypt/live/xyz.com/`:

    /etc/letsencrypt/live/xyz.com/cert.pem
    /etc/letsencrypt/live/xyz.com/chain.pem
    /etc/letsencrypt/live/xyz.com/fullchain.pem
    /etc/letsencrypt/live/xyz.com/privkey.pem

We only need two of them:

  - `privkey.pem`: the server's private key
  - `fullchain.pem`: the certificate and certificate chain.


## Variant B: Use a different certificate authority

You can also use a different CA. To do that, you first create a new
private key and certificate signing request&nbsp;(CSR). The file
[openssl.cnf](openssl.cnf) shows you what is necessary to create
a&nbsp;CSR for both `xyz.com` and&nbsp;`www.xyz.com`. The
`alt_names`&nbsp;section is relevant to cover both domains:

    [ alt_names ]
    DNS.1 = www.xyz.com
    DNS.2 = xyz.com

Using&nbsp;`openssl.cnf`, you can create the key&nbsp;(`server.key`)
and CSR&nbsp;(`server.csr`) for example with:

    $ openssl req -out server.csr -new -newkey rsa:2048 -nodes -keyout server.key -config openssl.cnf

You can inspect the created CSR with:

    $ openssl req -text -noout -verify -in server.csr

To obtain a certificate, you have again two options: Either use a
trusted&nbsp;CA (simply supply&nbsp;`server.csr`), or self-sign the
key using for example:

    $ openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt -extensions v3_req -extfile openssl.cnf

In both cases, the files that are important for the following are:

  - `server.key`: the server's private key
  - `server.crt`: the certificate and certificate chain.

Note that&mdash;up to naming&mdash;this corresponds to the files
obtained in Variant&nbsp;A.

# Running an HTTPS server with SWI-Prolog

In the previous section, we have seen two ways to obtain a private key
and a certificate. For clarity, we have used different file names to
distinguish the variants. We now assume the following files are
available in `/var/www/xyz.com/`, no matter which variant you used to
obtain them:

  - `server.key`: the server's private key
  - `server.crt`: the certificate and certificate chain.

**Note**: With SWI-Prolog&ge;7.3.30, you can store the certificate
and&nbsp;key in any location, and also *leave* the files in
`/etc/letsencrypt/live/` if you used *Let's&nbsp;Encrypt* to obtain
them. This is because recent versions of SWI-Prolog read these files
*before* dropping privileges when starting an HTTPS&nbsp;server.

As the name suggests, the private key is meant to be kept
*private*. Therefore, make sure to use suitable file permissions.

You can inspect the issued certificate with:

    $ openssl x509 -in server.crt -text -noout

## Preliminaries: SWI-Prolog web server as Unix daemon

The file [server.pl](server.pl) contains a very simple web server that
is written using SWI-Prolog. In its current form, it simply replies
with&nbsp;`Hello!` to any request. In a more realistic scenario, you
would of course supply a more suitable definition
of&nbsp;`handle_request/1`, so that the server replies with more
useful content. Still, this basic server suffices to illustrate the
principle for running an HTTPS&nbsp;server with any of the
certificates we obtained in the previous steps.

First, note that this server uses the [`http_unix_daemon`
library](http://eu.swi-prolog.org/pldoc/doc/swi/library/http/http_unix_daemon.pl).
This library makes it extremely easy to run the web&nbsp;server as a
Unix&nbsp;daemon by implicitly augmenting the code to let you
configure the server using command line&nbsp;options. If you have an
existing web server that you want to turn into a Unix daemon, apply
the following steps:

  - add `:- use_module(library(http/http_unix_daemon)).` at the beginning
  - add the directive `:- initialization http_daemon.`

Once you have done this, you can run the server with:

    $ swipl server.pl --port=PORT

and it will automatically launch as a daemon process. During
development, is is easier to work with the server on the terminal
using an interactive Prolog&nbsp;toplevel, which you can enable with:

<pre>
$ swipl server.pl --port=PORT <b>--interactive</b>
</pre>

To find out more available command line options, use:

    $ swipl server.pl --help

## Starting a Prolog HTTPS server

To start an HTTPS server with SWI-Prolog, the following 3 command line
options of the Unix daemon library are of particular relevance:

  - `--https`: enables HTTPS, using port 443 by default.
  - `--keyfile=FILE`: `FILE` contains the server's private key.
  - `--certfile=FILE`: `FILE` contains the certificate and certificate chain.

So, in our case, we can launch the HTTPS server for example with:

    $ sudo swipl server.pl --https --user=you --keyfile=/var/www/xyz.com/server.key --certfile=/var/www/xyz.com/server.crt

Note that running the server on port 443 requires root privileges. The
`--user`&nbsp;option is necessary to drop privileges to the specified
user after forking.

## Launching the HTTPS server on system startup

To launch the HTTPS server on system startup, have a look at the
`systemd` sample service file [`https.service`](https.service).

Adjust the file as necessary, copy it to `/etc/systemd/system` and enable it with

    $ sudo systemctl enable /etc/systemd/system/https.service

then start the service with:

    $ sudo systemctl start https.service

# Making your server more secure

Once your server is running, use for example
[SSL&nbsp;Labs](https://www.ssllabs.com/) to assess the quality of its
encryption settings.

As of 2016, it is possible to obtain an **A+** rating with SWI-Prolog
HTTPS servers, by using:

  - as ciphers (see command line option `--cipherlist`): `EECDH+AESGCM:EDH+AESGCM:EECDH+AES256:EDH+AES256`
  - the `Strict-Transport-Security` header field, to enable HSTS.

For additional security, you can encrypt the server's private key,
using for example:

    $ openssl rsa -des -in server.key -out server.enc

To use an encrypted key when starting the server, use the
`--pwfile=FILE` command line&nbsp;option of the HTTP Unix daemon,
where `FILE` stores the password and has suitably restrictive access
permissions.

# Renewing the certificate

Once you have a web server running, you can use *Let's Encrypt* to
obtain and *renew* your certificate *without stopping* the server.

To use this feature, you must configure your web server to serve any
files located in the directory&nbsp;**`.well-known`**. With the
SWI-Prolog HTTP&nbsp;infrastructure, you can do this by adding the
following directives to your&nbsp;server:

    :- use_module(library(http/http_files)).
    :- http_handler(root('.well-known/'), http_reply_from_files('.well-known', []), [prefix]).

Restart the server and use the `--webroot` option as in the following
example:

<pre>
$ sudo certbot certonly <b>--webroot</b> -w /var/www/xyz.com -d xyz.com -d www.xyz.com
</pre>

Please see `man certbot` for further options. For example, using
`--logs-dir`, `--config-dir` and `--work-dir`, you can configure paths
so that you can run `certbot` *without* root&nbsp;privileges. In the
example above, it is assumed that your web content is located in the
directory&nbsp;`/var/www/xyz.com`.

In this mode of operation, *Let's Encrypt* uses the existing web
server and file contents to verify that you control the domain.

After you have done this, you can renew the certificate any time with:

    $ certbot renew

This automatically renews certificates that will expire within
30&nbsp;days, again using the existing web server to establish you as
the owner of the&nbsp;domain. You can run this command as a cronjob.

After your certificate is renewed, you must restart your web server
for the change to take&nbsp;effect.

# Server Name Indication (SNI)

To host multiple domains from a single IP address, you need **Server
Name Indication**&nbsp;(SNI). This TLS&nbsp;extension lets you
indicate different certificates and keys depending on the
*host&nbsp;name* that the client accesses.

To use SNI, you need SWI-Prolog&ge;**7.3.31**.

The HTTP Unix daemon can be configured to use&nbsp;SNI by providing
suitable clauses of the predicate&nbsp;`http:sni_options/2`. The first
argument is the *host&nbsp;name*, and the second argument is a list of
SSL&nbsp;options for that domain. The most important options&nbsp;are:

  - `certificate_file(+File)`: file that contains the **certificate**
    and certificate&nbsp;chain
  - `key_file(+File)`: file that contains the **private key**.

For example, to specify a certificate and key for&nbsp;`abc.com`
and&nbsp;`www.abc.com`, we can&nbsp;use:

<pre>
http:sni_options('abc.com', [certificate_file(CertFile),key_file(KeyFile)]) :-
        CertFile = '/var/www/abc.com/server.crt',
        KeyFile = '/var/www/abc.com/server.key'.
http:sni_options('www.abc.com', Options) :-
        http:sni_options('abc.com', Options).
</pre>

# Exchanging certificates

SWI-Prolog&ge;**7.3.34** makes it possible to *exchange* certificates
while the&nbsp;server *keeps&nbsp;running*.

One way to do this is as follows:

1. Start your server *without* specifying a certificate or key.
2. Use the extensible predicate `http:ssl_server_create_hook/3` to add
   a certificate and key upon launch, while storing the original
   SSL&nbsp;context. See&nbsp;`ssl_add_certificate_key/4`.
3. When necessary, renew the certificate as explained above. Use
   `ssl_add_certificate_key/4` to add the new certificate to the
   original SSL&nbsp;context, obtaining a new&nbsp;context that is
   associated with the updated certificate.
4. Use the extensible predicate `http:ssl_server_open_client_hook/3`
   to use the new&nbsp;context when negotiating client connections.

See the [SSL documentation](http://eu.swi-prolog.org/pldoc/doc_for?object=section(%27packages/ssl.html%27))
for more information.

Using the original context as a baseline ensures that all command
line&nbsp;options are adhered to and copied to new contexts that are
created. For example, any specified *password* is securely retained in
contexts and can therefore be used also for newly created&nbsp;keys.

Note how [**logical purity**](https://www.metalevel.at/prolog/purity)
of these predicates allows the thread-safe implementation of a feature
that is not available in most other web&nbsp;servers.

# Related projects

Check out [**Proloxy**](https://github.com/triska/proloxy): It is a
*reverse&nbsp;proxy* that is written entirely in SWI-Prolog. Use
Proloxy if you want to provide access to different web&nbsp;services
under a common umbrella&nbsp;URL.

Importantly, you can run Proloxy as an HTTPS&nbsp;server and thus
encrypt traffic of all hosted services at once.

# Acknowledgments

All this is is made possible thanks to:

[**Jan Wielemaker**](http://eu.swi-prolog.org) for providing the
Prolog system that made all this possible in the first place.

[**Matt Lilley**](https://github.com/thetrime) for `library(ssl)`, the
SSL wrapper library that ships with SWI-Prolog. The SWI-Prolog HTTPS
server uses this library for secure connections.

[**Charlie Hothersall-Thomas**](https://charlie.ht/) for
implementation advice to enable more secure ciphers
in&nbsp;`library(ssl)`.
