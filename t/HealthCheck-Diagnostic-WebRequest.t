use strict;
use warnings;

use Test::More;
use Test::MockModule;
use HealthCheck::Diagnostic::WebRequest;

# Mock the HTTP response so that we don't actually end up making any
# HTTP requests while running tests.
sub mock_http_response {
    my (%params) = @_;

    my $mock = Test::MockModule->new( 'LWP::Protocol::https' );
    $mock->mock( request => sub {
        my ($self, $request, $proxy, $arg, $size, $timeout) = @_;

        # Borrowed and mocked from here: https://metacpan.org/source/OALDERS/libwww-perl-6.39/lib/LWP/Protocol/http.pm#L440
        my $response = HTTP::Response->new(
            $params{code}    // 200,
        );
        $response->{_content} = $params{content} // 'html_content';
        $response->protocol("HTTP/1.1");
        $response->push_header( @{ $params{headers} } );
        $response->request($request);

        return $response;
    });
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
    info   => 'Requested https://foo.com and got expected status code 200',
    status => 'OK',
}, 'Pass diagnostic check on status.' );

$mock = mock_http_response( code => 401 );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Requested https://foo.com and got status code 401, expected 200',
    status => 'CRITICAL',
}, 'Fail diagnostic check on status.' );

# Check that we get the right content responses.
$mock = mock_http_response( content => 'content_doesnt_exist' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://bar.com',
    content_regex => 'content_exists',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Requested https://bar.com and got expected status code 200'
            . '; Response content does not match /content_exists/',
    status => 'CRITICAL',
}, 'Fail diagnostic check on content.' );
$mock = mock_http_response( content => 'content_exists' );
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Requested https://bar.com and got expected status code 200'
            . '; Response content matches /content_exists/',
    status => 'OK',
}, 'Pass diagnostic check on content.' );

# Check that we skip the content match on status code failures.
$mock = mock_http_response( code => 300 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://cyprus.co',
    content_regex => 'match_check_should_not_happen',
);
is_deeply( get_info_and_status( $diagnostic ), {
    info   => 'Requested https://cyprus.co and got status code 300,'
            . ' expected 200',
    status => 'CRITICAL',
}, 'Do not look for content with failed status code check.' );

# Check that the content regex can be  a qr// variable.
$mock = mock_http_response( content => 'This is Disney World\'s site' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://disney.world',
    content_regex => qr/Disney/,
);
my $results = $diagnostic->check;
is $results->{status}, 'OK',
    'Pass diagnostic with regex content_regex.';
like $results->{info},
    qr/Response content matches .+Disney/,
    'Info message is correct.';

# Check content failure for appropriate message
$mock = mock_http_response( content => 'This is Disney World\'s site' );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
    content_regex => qr/fail_on_this/,
);
$results = $diagnostic->check;
is $results->{status}, 'CRITICAL',
    'Fail diagnostic with regex content_regex.';
like $results->{info},
    qr/Response content does not match .+fail_on_this/,
    'Info message is correct.';

# Check timeout failure for appropriate message
$mock = mock_http_response( code => 500,
    headers => ["Client-Warning" => "Internal response"]);
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
);
$results = $diagnostic->check;
is $results->{status}, 'CRITICAL', 'Timeout check';
like $results->{info}, qr/from internal response, expected 200/,
    'Internal timeout check';

# Check for proxy errors
$mock = mock_http_response( code => 403,
    headers => ["X-Squid-Error" => "ERR_ACCESS_DENIED 0"]);
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
);
$results = $diagnostic->check;
is $results->{status}, 'CRITICAL', 'Proxy status check';
like $results->{info}, qr/and got status code 403 from proxy/,
    'Proxy info message';

# Check < operator
$mock = mock_http_response( code => 401 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
    status_operator => '<',
    status_code => 500
);
$results = $diagnostic->check;
is $results->{status}, 'OK', 'Less than status check';
like $results->{info}, qr/and got expected status code 401/,
    'Valid less than message';

# Failed < operator with timeout
$mock = mock_http_response( code => 500,
    headers => ["Client-Warning" => "Internal response"]);
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
    status_operator => '<',
    status_code => 500
);
$results = $diagnostic->check;
is $results->{status}, 'CRITICAL', 'Failed less than status check';
like $results->{info}, qr/got status code 500 from internal response, expected value less than 500/,
    'Failed less than message with internal response timeout';

# Check valid ! operator
$mock = mock_http_response( code => 401 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
    status_operator => '!',
    status_code => 500
);

$results = $diagnostic->check;
is $results->{status}, 'OK', 'Less than status check';
like $results->{info}, qr/and got expected status code 401/,
    'Valid not message';

# Check failed ! operator
$mock = mock_http_response( code => 500 );
$diagnostic = HealthCheck::Diagnostic::WebRequest->new(
    url => 'https://fake.site.us',
    status_operator => '!',
    status_code => 500
);

$results = $diagnostic->check;
is $results->{status}, 'CRITICAL', 'failed NOT status check';
like $results->{info}, qr/expected NOT 500/,
# Make sure that we do not call `check` without an instance.
local $@;
eval { HealthCheck::Diagnostic::WebRequest->check };
like $@, qr/check cannot be called as a class method/,
    'Cannot call `check` without an instance.';


done_testing;
