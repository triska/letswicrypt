# LetSWICrypt &mdash; HTTPS servers with SWI-Prolog

This repository shows you how to set up and run a secure&nbsp;(HTTPS)
web&nbsp;server using SWI-Prolog and *Let's&nbsp;Encrypt* and other
certificate authorities.

# Requirements

The latest [git version of SWI-Prolog](https://github.com/SWI-Prolog)
ships with everything that is necessary to run HTTPS&nbsp;servers. Any
released version *greater* than&nbsp;7.3.20 will also work.

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

    $ ./letsencrypt-auto certonly --standalone -d xyz.com -d www.xyz.com

**Note**: This requires that you *stop* any server that listens on
port&nbsp;80 or port&nbsp;443 until the certificate is obtained.

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
distinguish the variants. In the following, we will assume the
following files are available in `/var/www/xyz.com/`, no matter which
variant you used to obtain them:

  - `server.key`: the server's private key
  - `server.crt`: the certificate and certificate chain.

As the name suggests, the private key is meant to be kept
*private*. Therefore, make sure to use suitable file permissions.

You can inspect the issued certificate with:

    $ openssl x509 -in server.crt -text -noout

## Preliminaries: SWI-Prolog web server as Unix daemon

SWI-Prolog is extremely well suited for writing web servers.

The file [server.pl](server.pl) contains a very simple web server that
is written using SWI-Prolog. In its current form, it simply replies
with a `404 Not found` error to any request. In a more
realistic scenario, you would of course supply a more suitable
definition for&nbsp;`handle_request/1`, so that the server replies
with more useful content. Still, this basic server suffices to
illustrate the principle for running an HTTPS&nbsp;server with any of
the certificates we obtained in the previous steps.

First, note that this server uses the [`http_unix_daemon`
library](http://www.swi-prolog.org/pldoc/doc/swi/library/http/http_unix_daemon.pl). This
library makes it extremely easy to run the web&nbsp;server as a
Unix&nbsp;daemon. If you have an existing web server that you want to
turn into a Unix daemon, apply the following steps:

  - add `:- use_module(library(http/http_unix_daemon)).` at the beginning
  - add the directive `:- initialization http_daemon.`

Once you have done this, you can run the server with:

    $ swipl server.pl --port=PORT

and it will automatically launch as a daemon process. During development,
is is easier to work with the server on the terminal, which you can do with:

<pre>
$ swipl server.pl --port=PORT <b>--interactive</b>
</pre>

To find out more available command line options, use:

    $ swipl server.pl --help

## Starting an HTTPS server

To start an HTTPS server, the following 3 command line options of the
Unix daemon library are of particular relevance:

  - `--https`: enables HTTPS, using port 443 by default.
  - `--keyfile=FILE`: `FILE` contains the server's private key.
  - `--certfile=FILE`: `FILE` contains the certificate and certificate chain.

So, in our case, we can launch the HTTPS server for example with:

    $ sudo swipl server.pl --https --user=you --keyfile=/var/www/xyz.com/server.key --certfile=/var/www/xyz.com/server.crt

Note that running the server on port 443 requires root privileges. The
`--user`&nbsp;option is necessary to drop privileges to the specified
user after forking.

## Running an HTTPS server on system startup

To launch the HTTPS server on system startup, have a look at the
`systemd` sample service file [`https.service`](https.service).

Adjust the file as necessary, copy it to `/etc/systemd/system` and enable it with

    $ sudo systemctl enable /etc/systemd/system/https.service

then start the service with:

    $ sudo systemctl start https.service

# Making your server more secure

Once your server is running, use for example
[SSL&nbsp;Labs](https://www.ssllabs.com/) to assess the security of
your cipher suite. See also the `--cipherlist` command line option for
the HTTP Unix&nbsp;daemon.

For additional security, you can encrypt the server's private key,
using for example:

    $ openssl rsa -des -in server.key -out server.enc

To use an encrypted key when starting the server, use the
`--pwfile=FILE` command line&nbsp;option of the HTTP Unix daemon,
where `FILE` stores the password and has suitably low access
permissions.

# Related projects

Check out [**Proloxy**](https://github.com/triska/proloxy): It is a
*reverse&nbsp;proxy* that is written entirely in SWI-Prolog. Use it if
you want to provide access to different web&nbsp;services under a
common umbrella&nbsp;URL. You can of course also run Proloxy as an
HTTPS&nbsp;server.

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
