#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";

use Site;
use Demo;
use Strehler::Admin;
Demo->dance;
