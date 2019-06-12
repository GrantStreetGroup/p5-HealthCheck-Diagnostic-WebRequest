use GSG::Gitc::CPANfile $_environment;

requires 'HealthCheck::Diagnostic';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';

test_requires 'Test::MockModule';

1;
