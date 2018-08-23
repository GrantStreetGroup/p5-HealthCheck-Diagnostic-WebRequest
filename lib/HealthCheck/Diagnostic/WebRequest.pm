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

    die "No external_site specified!" unless $params{external_site};

    return $class->SUPER::new(
        label => 'web_request',
        %params,
    );
}

sub run {
    my ( $self, %params ) = @_;

    my $response = LWP::UserAgent->new->get( $self->{external_site} );

    my @results = $self->check_status( $response );
    push @results, $self->check_content( $response )
        if $results[0]->{status} eq 'OK';

    my $info = join ';', map { $_->{info} } @results;

    return { info => $info, results => \@results };
}

sub check_status {
    my ( $self, $response ) = @_;

    my $expected_code = $self->{status_code} // 200;
    my $status = $expected_code == $response->code ? 'OK' : 'CRITICAL';

    my $info  = sprintf( "%s in requesting %s for %s status code",
        $status eq 'OK' ? 'Success' : 'Failure',
        $self->{external_site},
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

    my $site = 'https://www.grantsreet.com';

    # Look for a 200 status code and pass.
    my $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        external_site => $site,
    );
    my $result = $diagnostic->check;
    is $result->{info},
        'Success in requesting $site for 200 status code';
    is $result->{status}, 'OK';

    # Look for a 401 status code and fail.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        external_site => $site,
        status_code   => 401,
    );
    $result = $diagnostic->check;
    is $result->{info},
        'Failure in requesting $site for 401 status code (Got 200)';
    is $result->{status}, 'CRITICAL';

    # Look for a 200 status code and content matching the regex.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        external_site => $site,
        content_regex => "test",
    );
    $result = $diagnostic->check;
    is $result->{info},
        'Success in requesting $site for 200 status code;Response '.
        'content matches /test/';
    is $result->{status}, 'OK';

=head1 DESCRIPTION

Determine is a web request to an C<external_site> is achievable. Also
has the ability to check if the HTTP response contains the right
content, specified by C<content_regex>. Sets the C<status> to "OK" or
"CRITICAL" based on the success of the checks.

=head1 ATTRIBUTES

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>

=head1 CONFIGURATION AND ENVIRONMENT

None
