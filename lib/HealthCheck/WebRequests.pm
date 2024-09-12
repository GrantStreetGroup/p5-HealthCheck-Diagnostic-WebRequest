package HealthCheck::WebRequests;
use parent 'HealthCheck';

# ABSTRACT: Make HTTP/HTTPS requests to web servers to check connectivity
# VERSION

use strict;
use warnings;

use Carp;
use HealthCheck::Diagnostic::WebRequest;
use Scalar::Util 'blessed';

sub inflate_checks {
    my ($checks, $shared_attrs) = @_;

    my $type = ref $checks || '';
    if ($type eq 'ARRAY') {
        my @new_checks;
        for my $subcheck (@{ $checks }) {
            push @new_checks, inflate_checks($subcheck, $shared_attrs);
        }
        $checks = [ @new_checks ];
    }
    elsif ($type eq 'HASH') {
        $checks = HealthCheck::Diagnostic::WebRequest->new(
            %$shared_attrs,
            %$checks,
        )
    }

    return $checks;
}

sub verify_checks {
    my ($checks) = @_;

    return if blessed $checks && $checks->isa('HealthCheck::Diagnostic::WebRequest');

    my $type = ref $checks || '';
    if ($type eq 'ARRAY') {
        for my $subcheck (@{ $checks }) {
            verify_checks($subcheck);
        }
        return;
    }

    croak "Each registered check must be a HealthCheck::Diagnostic::WebRequest"
}

sub new {
    my ($class, @params) = @_;

    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    my @bad_params = grep {
        !/^(  checks
            | content_regex
            | id
            | label
            | no_follow_redirects
            | options
            | response_time_threshold
            | status_code
            | status_code_eval
            | runbook
            | tags
            | timeout
            | ua
        )$/x
    } keys %params;

    carp("Invalid parameter: " . join(", ", @bad_params)) if @bad_params;

    croak "No checks specified!" unless $params{checks};

    my %global_params = %params;
    delete $global_params{checks};
    $params{checks} = inflate_checks($params{checks}, \%global_params);

    return $class->SUPER::new(
        label => 'web_requests',
        %params,
    );
}

sub register {
    my ($self, $checks) = @_;

    verify_checks($checks);
    return $self->SUPER::register($checks);
}

1;
__END__

=head1 SYNOPSIS

    use HealthCheck::WebRequests;

    my $healthcheck = HealthCheck::WebRequests->new(
        checks => [
            {
                id    => 'foo',
                tags  => ['foo'],
                label => 'foo',
                url   => 'https://foo.example',
                # Any other valid args for HealthCheck::Diagnostic::WebRequest
            },
            HealthCheck::Diagnostic::WebRequest->new(...), # the top-level shared args do not apply to HealthCheck::Diagnostic::WebRequest instances
        ],
        # These args apply to all hashrefs in checks
        tags      => ['default_tag'],
        label     => 'default_label',
    );

    my $healthcheck2 = HealthCheck::WebRequests->new(
        checks => [
            {
                url   => 'https://foo.example',
                # tags        = ['default_tag']
                # label       = 'default_label'
                # status_code = '200'
            },
            {
                url   => 'https://bar.example',
                # tags        = ['default_tag']
                # label       = 'default_label'
                # status_code = '200'
            },
            HealthCheck::Diagnostic::WebRequest->new(...), # the top-level shared args do not apply to HealthCheck::Diagnostic::WebRequest instances
        ],
        # These args apply to all hashrefs in checks
        tags        => ['default_tag'],
        label       => 'default_label',
        status_code => '200',
    );


=head1 DESCRIPTION

A L<HealthCheck> that groups multiple L<HealthCheck::Diagnostic::WebRequest>.

=head1 ATTRIBUTES

=head2 checks

An arrayref of hashrefs, where each hashref should contain valid arguments to instantiate a
L<HealthCheck::Diagnostic::WebRequest> object. Alternatively,
L<L<HealthCheck::Diagnostic::WebRequest>> objects or subclasses can be directly provided instead of hashrefs.

=head1 SHARED ATTRIBUTES

These attributes, if supplied, are used to override the defaults for each hashref in the L<checks>. These will
not apply to any L<HealthCheck::Diagnostic::WebRequest> objects in L<checks>.

See the documentation in L<HealthCheck::Diagnostic::WebRequest> for more details on them.

=over

=item status_code

=item response_time_threshold

=item content_regex

=item no_follow_redirects

=item ua

=item options

=back

=head1 DEPENDENCIES

L<HealthCheck>
L<HealthCheck::Diagnostic::WebRequest>
L<LWP::UserAgent>

=head1 CONFIGURATION AND ENVIRONMENT

None
