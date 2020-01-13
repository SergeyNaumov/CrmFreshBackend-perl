function(value){
  let d2={},d3={},d4={};
  let rndstr=()=>{return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)};
  if(value == 1){ // скрыть dep2, dep3 и dep4
    d2.hide=true,d3.hide=true,d4.hide=true;
  }
  if(value==2){ // показать второй select
    d2.hide=false;
  }
  if(value==3){ // показать второй select, а также текстовые поля
    d2.hide=false,d3.hide=false,d4.hide=false
  }
  if(value==4){ // заполнить рандомно текстовые поля
    d3.hide=false, d4.hide=false,
    d3.value=rndstr(), d4.value=rndstr()
  }

  return [
      'dep2',d2,
      'dep3',d3,
      'dep4',d4
  ]
}