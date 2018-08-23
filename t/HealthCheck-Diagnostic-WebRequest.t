use strict;
use warnings;

use Test::More;
use Test::MockModule;
use HealthCheck::Diagnostic::WebRequest;

# Mock the HTTP response so that we don't actually end up making any
# HTTP requests while running tests.
sub mock_http_response {
    my (%params) = @_;
    my $response = bless( {
        _rc      => $params{code}    // 200,
        _content => $params{content} // 'html_content',
    }, 'HTTP::Response' );
    my $mock = Test::MockModule->new( 'LWP::UserAgent' );
    $mock->mock( get => $response );
    return $mock;
}

sub get_info_and_status {
    my ($diagnostic) = @_;

    my $results = $diagnostic->check;
    return { info => $results->{info}, status => $results->{status} };
}

# Check that we get the right code responses.
my $mock = mock_http_response();
my $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    external_site => 'https://foo.com',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://foo.com for 200 status code',
    status => 'OK',
}, 'Get a successful diagnostic check on status with right data.' );

$mock = mock_http_response( code => 401 );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Failure in requesting https://foo.com for 200 status '.
              'code (Got 401)',
    status => 'CRITICAL',
}, 'Get a failure diagnostic check on status with right data.' );

# Check that we get the right content responses.
$mock = mock_http_response( content => 'content_doesnt_exist' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    external_site => 'https://bar.com',
    content_regex => 'content_exists',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://bar.com for 200 status '.
              'code;Response content does not match /content_exists/',
    status => 'CRITICAL',
}, 'Get a failure diagnostic check on content with right data.' );
$mock = mock_http_response( content => 'content_exists' );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://bar.com for 200 status '.
              'code;Response content matches /content_exists/',
    status => 'OK',
}, 'Get a success diagnostic check on content with right data.' );

# Check that we skip the content match on status code failures.
$mock = mock_http_response( code => 300 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    external_site => 'https://cyprus.co',
    content_regex => 'match_check_should_not_happen',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Failure in requesting https://cyprus.co for 200 status '.
              'code (Got 300)',
    status => 'CRITICAL',
}, 'Do not look for content with unsuccessful status code.' );

done_testing;
