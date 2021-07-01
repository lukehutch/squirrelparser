//=========================================================================
//
//  This file was generated by Mouse 2.3 at 2021-06-29 10:41:47 GMT
//  from grammar '/tmp/Mouse-2.3/eq.peg'.
//
//=========================================================================

package eqn.mouse;

import mouse.runtime.Source;

public class MouseEqnParser extends mouse.runtime.ParserBase
{
  //=======================================================================
  //
  //  Initialization
  //
  //=======================================================================
  //-------------------------------------------------------------------
  //  Constructor
  //-------------------------------------------------------------------
  public MouseEqnParser()
    {
      sem = null;
      super.sem = sem;
    }
  
  //-------------------------------------------------------------------
  //  Run the parser
  //-------------------------------------------------------------------
  public boolean parse(Source src)
    {
      super.init(src);
      boolean result = Eqn();
      closeParser(result);
      return result;
    }
  
  //=======================================================================
  //
  //  Parsing procedures
  //
  //=======================================================================
  //=====================================================================
  //  Eqn = Prec0 ;
  //=====================================================================
  boolean Eqn()
    {
      begin("Eqn");
      if (!Prec0()) return reject();
      return accept();
    }
  
  //=====================================================================
  //  Prec4 = "(" Prec0 ")" ;
  //=====================================================================
  boolean Prec4()
    {
      begin("Prec4");
      if (!next('(')) return reject();
      if (!Prec0()) return reject();
      if (!next(')')) return reject();
      return accept();
    }
  
  //=====================================================================
  //  Prec3 = [0-9]+ / Prec4 ;
  //=====================================================================
  boolean Prec3()
    {
      begin("Prec3");
      if (Prec3_0()) return accept();
      if (Prec4()) return accept();
      return reject();
    }
  
  //-------------------------------------------------------------------
  //  Prec3_0 = [0-9]+
  //-------------------------------------------------------------------
  boolean Prec3_0()
    {
      begin("Prec3_0");
      if (!nextIn('0','9')) return rejectInner();
      while (nextIn('0','9'));
      return acceptInner();
    }
  
  //=====================================================================
  //  Prec2 = "-" Prec3 / Prec3 ;
  //=====================================================================
  boolean Prec2()
    {
      begin("Prec2");
      if (Prec2_0()) return accept();
      if (Prec3()) return accept();
      return reject();
    }
  
  //-------------------------------------------------------------------
  //  Prec2_0 = "-" Prec3
  //-------------------------------------------------------------------
  boolean Prec2_0()
    {
      begin("Prec2_0");
      if (!next('-')) return rejectInner();
      if (!Prec3()) return rejectInner();
      return acceptInner();
    }
  
  //=====================================================================
  //  Prec1 = Prec2 ("*" / "/") Prec2 / Prec2 ;
  //=====================================================================
  boolean Prec1()
    {
      begin("Prec1");
      if (Prec1_0()) return accept();
      if (Prec2()) return accept();
      return reject();
    }
  
  //-------------------------------------------------------------------
  //  Prec1_0 = Prec2 ("*" / "/") Prec2
  //-------------------------------------------------------------------
  boolean Prec1_0()
    {
      begin("Prec1_0");
      if (!Prec2()) return rejectInner();
      if (!next('*')
       && !next('/')
         ) return rejectInner();
      if (!Prec2()) return rejectInner();
      return acceptInner();
    }
  
  //=====================================================================
  //  Prec0 = Prec1 ("+" / "-") Prec1 / Prec1 ;
  //=====================================================================
  boolean Prec0()
    {
      begin("Prec0");
      if (Prec0_0()) return accept();
      if (Prec1()) return accept();
      return reject();
    }
  
  //-------------------------------------------------------------------
  //  Prec0_0 = Prec1 ("+" / "-") Prec1
  //-------------------------------------------------------------------
  boolean Prec0_0()
    {
      begin("Prec0_0");
      if (!Prec1()) return rejectInner();
      if (!next('+')
       && !next('-')
         ) return rejectInner();
      if (!Prec1()) return rejectInner();
      return acceptInner();
    }
  
}
