
function set_color_for_state_pr(){
  var color='#ffffff;'
  $('#state>option').each(
      function(n,option){
        if($(option).val() == $('#state').val()){
          color=$(option).css('backgroundColor')
          //console.log({n: n,v: $(option).val(),style: $(option).attr('style'),color: $(option).css('backgroundColor')});
        }
      }
  );

  $('#state_pr_indicator').css('backgroundColor',color);
}


function ball_operation(v){
  
  if(v==1 || v==-1){
      
      var cur_ball=parseInt($('#ball').text());
      console.log([cur_ball,v]);
      cur_ball=cur_ball+v;
      $.get('',
        {config:form.config,id:form.id,action:'ball_operation',value:v}
      ).done(
        function(res){
          
          $('#ball').text(res);
        }
      )
      
  }
}

$(document).ready(
  function(){
      $('a.ball_dec').click(function(){ball_operation(-1);return false});
      $('a.ball_inc').click(function(){ball_operation(1);return false});
  }
)

function delete_bill(bill_id){
  $.get(
    './edit_form.pl?config='+form.config+'&id='+form.id+'&action=delete_bill&bill_id='+bill_id
  ).done(
    function(res){
      if(res=='1'){
        $('#bill_'+bill_id).remove();
      }
      else{
        alert(res);
      }
      
    }
  );
  return false;
}
function create_new_bill(docpack_id){

  var summ=parseInt($('#nbs_'+docpack_id).val());
  if(!summ || !(/^\d+$/.test(summ)))
    return false;

  
  var comment=$('#nbc_'+docpack_id).val();
  
  $.post('./edit_form.pl',
      {
        config:form.config,
        id:form.id,
        docpack_id:docpack_id,
        action:'gen_new_bill',
        summ:summ,
        comment:comment?comment:'',
        get_bill_section:1,
      },
      function(res){
        $('#nbs_'+docpack_id).val('0');
        $('#docpack_'+docpack_id+' table').after(res);
      }
  );
  return false;
  
}

function edit_bill_comment(bill_id){
  var comment_txt=$('#for_edit_bill_comment_'+bill_id).text().
    replace(/^\s+/,'');
  comment_txt=(comment_txt.match(/\s*<нет комментария>\s*/))?'':comment_txt;
  
  bill_edit_form=$('#buff_bill_edit').html().
    replace(/\[bill_id\]/g,bill_id).
      replace(/\[bill_comment\]/,comment_txt);
  
  $('#for_edit_bill_comment_'+bill_id).html(bill_edit_form);
  
  return false;
}

function save_bill_comment(bill_id){
  var comment=$('#bill_comment_'+bill_id).val();
  $.post('./edit_form.pl',
    {
      config:form.config,
      id:form.id,
      action:'update_bill_comment',
      bill_id:bill_id,
      comment:comment,
    },
    function(data){
      if(data!='1'){
        alert(data);
      }
      if(comment.match(/^\s*$/))
        comment='<нет комментария>';
        
      var link=$('#buff_bill_comment').html().
        replace(/\[bill_id\]/g,bill_id).
          replace(/\[bill_comment\]/,comment);
      $('#for_edit_bill_comment_'+bill_id).html(link);
    }
  )
  return false;
}
