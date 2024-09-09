package HealthCheck::Diagnostic::WebRequests;
use parent 'HealthCheck::Diagnostic';

# ABSTRACT: Make HTTP/HTTPS requests to web servers to check connectivity
# VERSION

use strict;
use warnings;

use Carp;
use HealthCheck::Diagnostic::WebRequest;
use Scalar::Util 'blessed';

sub new {
    my ($class, @params) = @_;

    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    my @bad_params = grep {
        !/^(  content_regex
            | id
            | label
            | no_follow_redirects
            | options
            | response_time_threshold
            | status_code
            | status_code_eval
            | tags
            | timeout
            | ua
            | ua_action
            | web_request_diagnostics
        )$/x
    } keys %params;

    carp("Invalid parameter: " . join(", ", @bad_params)) if @bad_params;

    die "No web_request_diagnostics specified!" unless $params{web_request_diagnostics};

    my %global_params = %params;
    delete $global_params{web_request_diagnostics};

    $params{web_request_diagnostics} = [ map {
        blessed $_ && $_->isa('HealthCheck::Diagnostic::WebRequest') ? $_ : HealthCheck::Diagnostic::WebRequest->new(
            %global_params,
            %$_,
        );
    } @{ $params{web_request_diagnostics} } ];

    return $class->SUPER::new(
        label => 'web_requests',
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
    return ( results => [ map { $_->check } @{ $self->{web_request_diagnostics} } ] );
}

1;
__END__

=head1 SYNOPSIS

    # sites:    https://foo.com, https://bar.com

    use HealthCheck::Diagnostic::WebRequests;

    my $diagnostic = HealthCheck::Diagnostic::WebRequests->new(
        web_request_diagnostics => [
            {
                id    => 'foo',
                tags  => ['foo'],
                label => 'foo',
                url   => 'https://foo.com',
                # Any other valid args for HealthCheck::Diagnostic::WebRequest
            }
        ],
        # These args apply to all newly created HealthCheck::Diagnostic::WebRequest instances unless overridden
        ua_action => sub { ... },
        tags      => ['default_tag'],
        label     => 'default_label',
    );


=head1 DESCRIPTION

A wrapper around L<HealthCheck::Diagnostic::WebRequest> that groups multiple
requests into a single healthcheck. This class will effectively create a
L<HealthCheck::Diagnostic::WebRequest> instance for each provided URL in
C<web_request_diagnostics> and call its C<check> method. L<HealthCheck::Diagnostic::WebRequest>
objects can also be directly passed in the C<web_request_diagnostics> arrayref.

=head1 ATTRIBUTES

=head2 web_request_diagnostics

An arrayref of hashrefs, where each hashref should contain valid arguments to instantiate a
L<HealthCheck::Diagnostic::WebRequest> object. Alternatively,
L<L<HealthCheck::Diagnostic::WebRequest>> objects can be directly provided instead of a hashrefs.

=head2 status_code

The expected HTTP response status code, or a string of status code conditions.

Conditions are comma-delimited, and can optionally have an operator prefix. Any
condition without a prefix goes into an C<OR> set, while the prefixed ones go
into an C<AND> set. As such, C<==> is not allowed as a prefix, because it's less
confusing to not use a prefix here, and more than one condition while a C<==>
condition exists would not make sense.

Some examples:

    !500              # Anything besides 500
    200, 202          # 200 or 202
    200, >=300, <400  # 200 or any 3xx code
    <400, 405, !202   # Any code below 400 except 202, or 405,
                      # ie: (<400 && !202) || 405

The default value for this is '200', which means that we expect a successful request.

=head2 response_time_threshold

An optional number of seconds to compare the response time to. If it takes no more
than this threshold to receive the response, the status is C<OK>. If the time exceeds
this threshold, the status is C<WARNING>.

=head2 content_regex

The content regex to test for in the HTTP response.
This is an optional field and is only checked if the status
code check passes.
This can either be a I<string> or a I<regex>.

=head2 no_follow_redirects

Setting this variable prevents the healthcheck from following redirects.

=head2 ua

An optional attribute to override the default user agent. This must be of type L<LWP::UserAgent>.

=head2 ua_action

An optional attribute to override the default coderef that sends a request via the user agent object.
This function should return a valid HTTP response.

=head2 options

See L<LWP::UserAgent> for available options. Takes a hash reference of key/value
pairs in order to configure things like ssl_opts, timeout, etc.

It is optional.

By default provides a custom C<agent> string and a default C<timeout> of 7.

=head1 DEPENDENCIES

L<HealthCheck::Diagnostic>
L<HealthCheck::Diagnostic::WebRequest>
L<LWP::UserAgent>

=head1 CONFIGURATION AND ENVIRONMENT

None
