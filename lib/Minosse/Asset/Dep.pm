package Minosse::Asset::Dep;
use Deeme::Obj -base;
has [qw(module version type )];
has 'is_requirement' => sub {1};
1;
