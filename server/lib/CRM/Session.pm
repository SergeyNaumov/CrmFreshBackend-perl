package CRM::Session;
use strict;
use utf8;
sub create{ # создание сессии
	my %arg=@_;

	my $s=$arg{s};
    my $form=$arg{form};
    my $R=$arg{R}; # json request data
    my $errors=[];
    if(!$arg{auth_table}){
        return 'При создании сесси: не указана auth_table'; return;
    }
    
    if(!$arg{login}){
        $arg{login}=$R->{login};
        unless(defined($arg{login}) ){
            return 'При создании сессии (не указан login)'; return;
        }
    }
    
    if(!$arg{password}){
        $arg{password}=$R->{password};
        unless(defined($arg{password})){
            return 'При создании сессии (не указан password)'; return ;
        }   
    }
    
    if(!$arg{auth_id_field}){
        return 'При создании сессии (не указан auth_id_field)'; return;
    }

    # Таблица, по кот. будем проверять логин и пароль
    
    $arg{auth_log_field}='login' unless($arg{auth_log_field});
    $arg{auth_pas_field}='password' unless($arg{auth_pas_field}); 
    $arg{session_table}='session' unless($arg{session_table});    
    
    # 1. Узнаём идентификатор записи того, кто логинится:
    my $add_where='';
    if($arg{where}){
        $add_where=qq{ AND $arg{where}};
    }

    # проверяем, сколько было попыток зайти с данного логина
    if($arg{max_fails_login}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from session_fails where login=? and registered>=now() - interval ? second',
            values=>[$arg{login},$arg{max_fails_login_interval}],
            onevalue=>1,
            errors=>$errors
        );
        
        if($fails>$arg{max_fails_login}){
            return 'Ошибка безопасности: превышено максимальное количество входа по логину';
            
        }
    }
    # проверяем, сколько было попыток зайти с данного ip под данным паролем
    if($arg{max_fails_ip}=~m{^\d+$} && $arg{max_fails_login_interval}=~m{^\d+$}){
        my $fails=$arg{connect}->query(
            query=>'select count(*) from session_fails where ip=? and registered>=now() - interval ? second',
            values=>[$arg{ip},$arg{max_fails_ip_interval}],
            onevalue=>1,
            errors=>$errors
        );
        if($fails>$arg{max_fails_ip}){
            return 'Ошибка безопасности: превышено максимальное количество входа по IP';
            
        }
    }
    

    my $auth_id;
    if($arg{encrypt_method} eq 'mysql_encrypt'){ # пароль зашифрован с помощью функции encrypt
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM $arg{auth_table} WHERE $arg{auth_log_field}=? AND $arg{auth_pas_field}=ENCRYPT(?,password) $add_where",
            values=>[$arg{login}, $arg{password}],
            onevalue=>1
        );
    }
    else{
        $auth_id=$arg{connect}->query(
            query=>"SELECT $arg{auth_id_field} FROM $arg{auth_table} WHERE $arg{auth_log_field}=? AND $arg{auth_pas_field}=? $add_where",
            values=>[$arg{login}, $arg{password}],
            onevalue=>1
        );
    }


    #print "encrypt_method: $arg{encrypt_method}\n";
    #print "auth_id: $auth_id\n";

    
    if($auth_id){ # залогинились
        
        # 3. Генерируем ключ сессии
        # my $a='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
        # my $key='';
        # foreach my $k (1..200){
        #     $key.=substr($a,int(rand(length($a))),1)
        # }
        my $key=$s->gen_pas(200);

        # 4. Делаем запись в таблицу сессий
        $arg{connect}->save(
            table=>$arg{session_table},
            data=>{
                auth_id=>$auth_id,
                session_key=>$key,
                registered=>'func::now()',
            }
        );
        
        #print "SET cookie!\n";
        $s->set_cookie(name=>'auth_user_id',value=>$auth_id);
        $s->set_cookie(name=>'auth_key',value=>$key);

        
    }
    else{
        $arg{connect}->save(
            table=>'session_fails',
            data=>{
                login=>$arg{login},
                registered=>'func::now()',
                ip=>$arg{ip}
            }

        );
        return 'авторизационные данные неверны';
    }
    return {
        errors=>$errors,
        success=>scalar(@{$errors})?0:1
    };
}
sub start{
    my %arg=@_;
    my $s=$arg{s};



    my $user_id=$s->get_cookie('auth_user_id');
    my $key=$s->get_cookie('auth_key');
    $arg{session_table}='session' unless($arg{session_table}); 
    my $errors=[];
    my $ok=$arg{connect}->query(
            query=>"SELECT count(*) FROM $arg{session_table} WHERE auth_id=? and session_key=?",
            values=>[$user_id, $key],
            onevalue=>1,
            errors=>$errors
    );
    if($ok){
        my $login=$arg{connect}->query(query=>'select login from manager where id=?',values=>[$user_id],onevalue=>1,errors=>$errors);
        return {login=>$login?$login:'',errors=>$errors};
    }
    return {login=>'',errors=>$errors};

    
    


}
sub logout{
    my %arg=@_;

    my $s=$arg{s}; 
    
    
    
    $arg{session_table}='session' unless($arg{session_table});
            
    my $user_id=$s->get_cookie('auth_user_id');
    my $key=$s->get_cookie('auth_key');

    if($user_id=~m/^\d+$/ && $key){       
        $arg{connect}->query(query=>"DELETE FROM $arg{session_table} WHERE auth_id=? and session_key=?",values=>[$user_id,$key]);
    }
    
}
return 1;