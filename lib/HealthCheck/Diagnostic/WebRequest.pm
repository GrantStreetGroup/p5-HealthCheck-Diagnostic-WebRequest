package HealthCheck::Diagnostic::WebRequest;
use parent 'HealthCheck::Diagnostic';

# ABSTRACT: Make HTTP/HTTPS requests to web servers to check connectivity
# VERSION

use strict;
use warnings;

use Carp;
use LWP::UserAgent;

sub new {
    my ($class, @params) = @_;

    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    die "No url specified!" unless $params{url};

    return $class->SUPER::new(
        label => 'web_request',
        %params,
    );
}

sub check {
    my ($self, @args) = @_;

    croak("check cannot be called as a class method")
        unless ref $self;
    return $self->SUPER::check(@args);
}

sub run {
    my ( $self, %params ) = @_;

    my $response = LWP::UserAgent->new->get( $self->{url} );

    my @results = $self->check_status( $response );
    push @results, $self->check_content( $response )
        if $results[0]->{status} eq 'OK';

    my $info = join '; ', map { $_->{info} } @results;

    return { info => $info, results => \@results };
}

sub check_status {
    my ( $self, $response ) = @_;

    my $expected_code = $self->{status_code} // 200;
    my $status = $expected_code == $response->code ? 'OK' : 'CRITICAL';

    my $info  = sprintf( "Requested %s and %s got status code %s",
        $self->{url},
        $status eq 'OK' ? 'successfully' : 'unsuccessfully',
        $expected_code,
    );
    $info .= " (Got ".$response->code.")" unless $status eq 'OK';

    return { status => $status, info   => $info };
}

sub check_content {
    my ( $self, $response ) = @_;

    return unless $self->{content_regex};

    my $regex      = $self->{content_regex};
    my $content    = $response->content;
    my $status     = $content =~ /$regex/ ? 'OK' : 'CRITICAL';
    my $successful = $status eq 'OK' ? 'matches' : 'does not match';

    return {
        status => $status,
        info   => "Response content $successful /$regex/",
    };
}

1;
__END__

=head1 SYNOPSIS

    # site:    https://foo.com
    # content: <html><head></head><body>This is my content</body></html>

    use HealthCheck::Diagnostic::WebRequest;

    # Look for a 200 status code and pass.
    my $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url => 'https://foo.com',
    );
    my $result = $diagnostic->check;
    print $result->{status}; # OK

    # Look for a 401 status code and fail.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url         => 'https://foo.com',
        status_code => 401,
    );
    $result = $diagnostic->check;
    print $result->{status}; # CRITICAL

    # Look for a 200 status code and content matching the string regex.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url           => 'https://foo.com',
        content_regex => 'is my',
    );
    $result = $diagnostic->check;
    print $result->{status}; # OK

    # Use a regex as the content_regex.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url           => 'https://foo.com',
        content_regex => qr/is my/,
    );
    $result = $diagnostic->check;
    print $result->{status}; # OK

=head1 DESCRIPTION

Determines if a web request to a C<url> is achievable.
Also has the ability to check if the HTTP response contains the
right content, specified by C<content_regex>. Sets the C<status> to "OK"
or "CRITICAL" based on the success of the checks.

=head1 ATTRIBUTES

=head2 url

The site that is checked during the HealthCheck.
It can be any HTTP or HTTPS link.

It is required.

=head2 status_code

The expected HTTP response status code.
The default value for this is 200,
which means that we expect a successful request.

=head2 content_regex

The content regex to test for in the HTTP response.
This is an optional field and is only checked if the status
code check passes.
This can either be a I<string> or a I<regex>.

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>
L<LWP::UserAgent>

=head1 CONFIGURATION AND ENVIRONMENT

None
