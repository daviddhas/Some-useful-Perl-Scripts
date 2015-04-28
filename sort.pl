    #!/usr/bin/perl
    use strict;
    use warnings;
    use 5.010;


    use feature qw(say switch);
     
    use Data::Dumper qw(Dumper);
     
    my @words = qw(Foo bar zorg moo);
     
    say Dumper \@words;
     
    my @sorted_words = sort @words;
     
    say Dumper \@sorted_words;

    @sorted_words = sort { lc($a) cmp lc($b) } @words;
   
    say Dumper \@sorted_words;
