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
    url => 'https://foo.com',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://foo.com for 200 status code',
    status => 'OK',
}, 'Pass diagnostic check on status.' );

$mock = mock_http_response( code => 401 );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Failure in requesting https://foo.com for 200 status '.
              'code (Got 401)',
    status => 'CRITICAL',
}, 'Fail diagnostic check on status.' );

# Check that we get the right content responses.
$mock = mock_http_response( content => 'content_doesnt_exist' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://bar.com',
    content_regex => 'content_exists',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://bar.com for 200 status '.
              'code; Response content does not match /content_exists/',
    status => 'CRITICAL',
}, 'Fail diagnostic check on content.' );
$mock = mock_http_response( content => 'content_exists' );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://bar.com for 200 status '.
              'code; Response content matches /content_exists/',
    status => 'OK',
}, 'Pass diagnostic check on content.' );

# Check that we skip the content match on status code failures.
$mock = mock_http_response( code => 300 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://cyprus.co',
    content_regex => 'match_check_should_not_happen',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Failure in requesting https://cyprus.co for 200 status '.
              'code (Got 300)',
    status => 'CRITICAL',
}, 'Do not look for content with failed status code check.' );

# Check that the content regex can be  a qr// variable.
$mock = mock_http_response( content => 'This is Disney World\'s site' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://disney.world',
    content_regex => qr/Disney/,
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting https://disney.world for 200 '.
              'status code; Response content matches /(?^:Disney)/',
    status => 'OK',
}, 'Pass diagnostic with regex content_regex.' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'http://fake.site.us',
    content_regex => qr/fail_on_this/,
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Success in requesting http://fake.site.us for 200 '.
              'status code; Response content does not match '.
              '/(?^:fail_on_this)/',
    status => 'CRITICAL',
}, 'Fail diagnostic with regex content_regex.' );

# Make sure that we do not call `check` without an instance.
local $@;
eval { HealthCheck::Diagnostic::WebRequest->check };
like $@, qr/check cannot be called as a class method/,
    'Cannot call `check` without an instance.';


done_testing;
