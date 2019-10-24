use GSG::Gitc::CPANfile $_environment;

requires 'HealthCheck::Diagnostic';
requires 'LWP::UserAgent';
requires 'HTTP::Request';

test_requires 'Test::MockModule';

1;
on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG::Internal';
};
