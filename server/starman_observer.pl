#!/usr/bin/perl
use Data::Dumper;
my $port=$ARGV[0]; my $timeout=3; my $restart_time=0;

my $debug=0;
my $dirs=[
    './lib'
];
unless($port=~m/^\d+$/){
    $port=5000
}
#print "port: $port\n";
#print changed_files();
#№exit;

while(1){
    if(my $pid=get_pid()){
        #foreach(1..100){
            if(changed_files()){ # если файлы менялись -- перезапускаем
                $restart_time=time();
                print "restart starman\n" if($debug);;
                `kill -s SIGHUP $pid`
            }
            else{
                #print "not changes\n";
            }
            sleep $timeout;
        #}


    }
    else{
        # Если нет PID-а -- запускаем
        $restart_time=time();
        print "run server\n" if($debug);
        my $err=`perl -t work.psgi` ;
        print "err: $err";
        if(!$err){
            `perl -t work.psgi 2 && starman --daemonize --port=$port work.psgi`;
        }
        
        
    }
    sleep $timeout;
}

sub get_pid{
    my @process=split(/\n/,`ps ax | grep 'starman master --daemonize --port=$port work.psgi' | grep -v grep`);
    if(scalar(@process)){
        if($process[0]=~m/\s*(\d+)/){
            return $1;
        }
    }
    return undef
}
sub changed_files{ # если файлы менялись менее чем $timeout назад -- перезапускаем
    foreach my $d (@{$dirs}){
        foreach my $f ( grep { -f $_} split /\n/,`find $d` ){
            my $mtime=(stat($f))[9];
            #print "$f $mtime $restart_time\n";
            if($mtime>$restart_time){
                return 1;
            }
        }
    }
    return 0;
}
sub pre{
    print Dumper($_[0])
}