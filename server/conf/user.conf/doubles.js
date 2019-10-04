$(document).ready(
  function(){
    //$('table#docpack').css('width','100%');
    $('table#docpack').closest('.full_str').css('padding','10px');
    $('table#docpack').css('width','100%');
    $('table#1_to_m_docpack img').css('margin-bottom','10px;');
    
    $('a#link_new_1_to_m_contacts').click(
      function(){
        
        if($('form input[name=action]').val() == 'insert'){ // если новая карта
          init_contacts_check();
        }
      }
    )
  }
);

function init_contacts_check(){
      // phone
      $('#contacts_1_to_m_1 input[name=contacts_1_to_m_phone]').keyup(
        function(){
          var phone=$(this).val();
          var arr=$(this).attr('id').match(/^contacts_1_to_m_contacts_1_to_m_phone_(\d+)/);
          var check='#for_check_contacts_1_to_m_contacts_1_to_m_phone_'+arr[1];          
          if(phone.match(/^\+\d{6}\d*$/)){
            
            $(this).css('background','');
            $.ajax({
              url: '?',
              data: {config:form.config,phone:phone,action:'find_doubles'},
              success: function(data){
                $(check).html(data);
                if(data.match(/найдены дубли/)){
                  $('input[type="submit"]').prop('disabled', true);
                }
                else{
                  //console.log(2);
                  $('input[type="submit"]').prop('disabled', false);
                }
              },
            });
          }
          else{
            $('input[type="submit"]').prop('disabled', true);
            $(this).css('background','red');
            $(check).html('');
          }
        }
      );
      // email
      $('#contacts_1_to_m_1 input[name=contacts_1_to_m_email]').keyup(
        function(){
          var email=$(this).val();
          var arr=$(this).attr('id').match(/^contacts_1_to_m_contacts_1_to_m_email_(\d+)/);
          var check='#for_check_contacts_1_to_m_contacts_1_to_m_email_'+arr[1];
          if(email.match(/^[^\s]+@[^\s]+\.[^\s]+$/)){
            $(this).css('background','');

            
            //console.log(arr[1]);
            $.ajax({
              url: '?',
              data: {config:form.config,email:email,action:'find_doubles'},
              success: function(data){
                $(check).html(data);
                if(data.match(/найдены дубли/)){
                  $('input[type="submit"]').prop('disabled', true);
                }
                else{
                  //console.log(2);
                  $('input[type="submit"]').prop('disabled', false);
                }
              },
            });
          }
          else{
            $('input[type="submit"]').prop('disabled', true);
            $(this).css('background','red');
            $(check).html('');
          }
        }
      );  
}

