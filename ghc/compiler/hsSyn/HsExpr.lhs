%
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1998
%
\section[HsExpr]{Abstract Haskell syntax: expressions}

\begin{code}
module HsExpr where

#include "HsVersions.h"

-- friends:
import HsDecls		( HsGroup )
import HsPat		( LPat )
import HsLit		( HsLit(..), HsOverLit )
import HsTypes		( LHsType, PostTcType, SyntaxName )
import HsImpExp		( isOperator, pprHsVar )
import HsBinds		( HsBindGroup )

-- others:
import Type		( Type, pprParendType )
import Var		( TyVar, Id )
import Name		( Name )
import DataCon		( DataCon )
import BasicTypes	( IPName, Boxity, tupleParens, Fixity(..) )
import SrcLoc		( Located(..), unLoc )
import Outputable	
import FastString
\end{code}


%************************************************************************
%*									*
\subsection{Expressions proper}
%*									*
%************************************************************************

\begin{code}
type LHsExpr id = Located (HsExpr id)

data HsExpr id
  = HsVar	id		-- variable
  | HsIPVar	(IPName id)	-- implicit parameter
  | HsOverLit	HsOverLit	-- Overloaded literals; eliminated by type checker
  | HsLit	HsLit		-- Simple (non-overloaded) literals

  | HsLam	(LMatch  id)	-- lambda
  | HsApp	(LHsExpr id)	-- application
		(LHsExpr id)

  -- Operator applications:
  -- NB Bracketed ops such as (+) come out as Vars.

  -- NB We need an expr for the operator in an OpApp/Section since
  -- the typechecker may need to apply the operator to a few types.

  | OpApp	(LHsExpr id)	-- left operand
		(LHsExpr id)	-- operator
		Fixity		-- Renamer adds fixity; bottom until then
		(LHsExpr id)	-- right operand

  -- We preserve prefix negation and parenthesis for the precedence parser.
  -- They are eventually removed by the type checker.

  | NegApp	(LHsExpr id)	-- negated expr
		SyntaxName	-- Name of 'negate' (see RnEnv.lookupSyntaxName)

  | HsPar	(LHsExpr id)	-- parenthesised expr

  | SectionL	(LHsExpr id)	-- operand
		(LHsExpr id)	-- operator
  | SectionR	(LHsExpr id)	-- operator
		(LHsExpr id)	-- operand
				
  | HsCase	(LHsExpr id)
		[LMatch id]

  | HsIf	(LHsExpr id)	--  predicate
		(LHsExpr id)	--  then part
		(LHsExpr id)	--  else part

  | HsLet	[HsBindGroup id] -- let(rec)
		(LHsExpr  id)

  | HsDo	(HsStmtContext Name)	-- The parameterisation is unimportant
					-- because in this context we never use
					-- the PatGuard or ParStmt variant
		[LStmt id]		-- "do":one or more stmts
		(ReboundNames id)	-- Ids for [return,fail,>>=,>>]
			PostTcType	-- Type of the whole expression

  | ExplicitList		-- syntactic list
		PostTcType	-- Gives type of components of list
		[LHsExpr id]

  | ExplicitPArr		-- syntactic parallel array: [:e1, ..., en:]
		PostTcType	-- type of elements of the parallel array
		[LHsExpr id]

  | ExplicitTuple		-- tuple
		[LHsExpr id]
				-- NB: Unit is ExplicitTuple []
				-- for tuples, we can get the types
				-- direct from the components
		Boxity


	-- Record construction
  | RecordCon	(Located id)		-- The constructor
		(HsRecordBinds id)

  | RecordConOut DataCon
		(LHsExpr id)		-- Data con Id applied to type args
		(HsRecordBinds id)


	-- Record update
  | RecordUpd	(LHsExpr id)
		(HsRecordBinds id)

  | RecordUpdOut (LHsExpr id)	-- TRANSLATION
		 Type			-- Type of *input* record
		 Type			-- Type of *result* record (may differ from
					-- 	type of input record)
		 (HsRecordBinds id)

  | ExprWithTySig			-- e :: type
		(LHsExpr id)
		(LHsType id)

  | ExprWithTySigOut			-- TRANSLATION
		(LHsExpr id)
		(LHsType Name)		-- Retain the signature for round-tripping purposes

  | ArithSeqIn				-- arithmetic sequence
		(ArithSeqInfo id)
  | ArithSeqOut
		(LHsExpr id)		-- (typechecked, of course)
		(ArithSeqInfo id)
  | PArrSeqIn           		-- arith. sequence for parallel array
		(ArithSeqInfo id)	-- [:e1..e2:] or [:e1, e2..e3:]
  | PArrSeqOut
		(LHsExpr id)		-- (typechecked, of course)
		(ArithSeqInfo id)

  | HsSCC	FastString	-- "set cost centre" (_scc_) annotation
		(LHsExpr id) 	-- expr whose cost is to be measured

  | HsCoreAnn   FastString      -- hdaume: core annotation
                (LHsExpr id)
		
  -----------------------------------------------------------
  -- MetaHaskell Extensions
  | HsBracket    (HsBracket id)

  | HsBracketOut (HsBracket Name)	-- Output of the type checker is the *original*
		 [PendingSplice]	-- renamed expression, plus *typechecked* splices
					-- to be pasted back in by the desugarer

  | HsSpliceE (HsSplice id) 

  -----------------------------------------------------------
  -- Arrow notation extension

  | HsProc	(LPat id)		-- arrow abstraction, proc
		(LHsCmdTop id)		-- body of the abstraction
					-- always has an empty stack

  ---------------------------------------
  -- The following are commands, not expressions proper

  | HsArrApp	-- Arrow tail, or arrow application (f -< arg)
	(LHsExpr id)	-- arrow expression, f
	(LHsExpr id)	-- input expression, arg
	PostTcType	-- type of the arrow expressions f,
			-- of the form a t t', where arg :: t
	HsArrAppType	-- higher-order (-<<) or first-order (-<)
	Bool		-- True => right-to-left (f -< arg)
			-- False => left-to-right (arg >- f)

  | HsArrForm	-- Command formation,  (| e cmd1 .. cmdn |)
	(LHsExpr id)	-- the operator
			-- after type-checking, a type abstraction to be
			-- applied to the type of the local environment tuple
	(Maybe Fixity)	-- fixity (filled in by the renamer), for forms that
			-- were converted from OpApp's by the renamer
	[LHsCmdTop id]	-- argument commands
\end{code}


These constructors only appear temporarily in the parser.
The renamer translates them into the Right Thing.

\begin{code}
  | EWildPat			-- wildcard

  | EAsPat	(Located id)	-- as pattern
		(LHsExpr id)

  | ELazyPat	(LHsExpr id) -- ~ pattern

  | HsType      (LHsType id)     -- Explicit type argument; e.g  f {| Int |} x y
\end{code}

Everything from here on appears only in typechecker output.

\begin{code}
  | TyLam			-- TRANSLATION
		[TyVar]
		(LHsExpr id)
  | TyApp			-- TRANSLATION
		(LHsExpr id) -- generated by Spec
		[Type]

  -- DictLam and DictApp are "inverses"
  |  DictLam
		[id]
		(LHsExpr id)
  |  DictApp
		(LHsExpr id)
		[id]

type PendingSplice = (Name, LHsExpr Id)	-- Typechecked splices, waiting to be 
					-- pasted back in by the desugarer
\end{code}

Table of bindings of names used in rebindable syntax.
This gets filled in by the renamer.

\begin{code}
type ReboundNames id = [(Name, HsExpr id)]
-- * Before the renamer, this list is empty
--
-- * After the renamer, it takes the form [(std_name, HsVar actual_name)]
--   For example, for the 'return' op of a monad
--	normal case:		(GHC.Base.return, HsVar GHC.Base.return)
--	with rebindable syntax:	(GHC.Base.return, return_22)
--		where return_22 is whatever "return" is in scope
--
-- * After the type checker, it takes the form [(std_name, <expression>)]
--	where <expression> is the evidence for the method
\end{code}

A @Dictionary@, unless of length 0 or 1, becomes a tuple.  A
@ClassDictLam dictvars methods expr@ is, therefore:
\begin{verbatim}
\ x -> case x of ( dictvars-and-methods-tuple ) -> expr
\end{verbatim}

\begin{code}
instance OutputableBndr id => Outputable (HsExpr id) where
    ppr expr = pprExpr expr
\end{code}

\begin{code}
pprExpr :: OutputableBndr id => HsExpr id -> SDoc

pprExpr  e = pprDeeper (ppr_expr e)

pprBinds :: OutputableBndr id => [HsBindGroup id] -> SDoc
pprBinds b = pprDeeper (vcat (map ppr b))

ppr_lexpr :: OutputableBndr id => LHsExpr id -> SDoc
ppr_lexpr e = ppr_expr (unLoc e)

ppr_expr (HsVar v)	 = pprHsVar v
ppr_expr (HsIPVar v)     = ppr v
ppr_expr (HsLit lit)     = ppr lit
ppr_expr (HsOverLit lit) = ppr lit

ppr_expr (HsLam match) = pprMatch LambdaExpr (unLoc match)

ppr_expr (HsApp e1 e2)
  = let (fun, args) = collect_args e1 [e2] in
    (ppr_lexpr fun) <+> (sep (map pprParendExpr args))
  where
    collect_args (L _ (HsApp fun arg)) args = collect_args fun (arg:args)
    collect_args fun args = (fun, args)

ppr_expr (OpApp e1 op fixity e2)
  = case unLoc op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_e1 = pprParendExpr e1		-- Add parens to make precedence clear
    pp_e2 = pprParendExpr e2

    pp_prefixly
      = hang (ppr op) 4 (sep [pp_e1, pp_e2])

    pp_infixly v
      = sep [pp_e1, hsep [pprInfix v, pp_e2]]

ppr_expr (NegApp e _) = char '-' <+> pprParendExpr e

ppr_expr (HsPar e) = parens (ppr_lexpr e)

ppr_expr (SectionL expr op)
  = case unLoc op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_expr = pprParendExpr expr

    pp_prefixly = hang (hsep [text " \\ x_ ->", ppr op])
		       4 (hsep [pp_expr, ptext SLIT("x_ )")])
    pp_infixly v = parens (sep [pp_expr, ppr v])

ppr_expr (SectionR op expr)
  = case unLoc op of
      HsVar v -> pp_infixly v
      _	      -> pp_prefixly
  where
    pp_expr = pprParendExpr expr

    pp_prefixly = hang (hsep [text "( \\ x_ ->", ppr op, ptext SLIT("x_")])
		       4 ((<>) pp_expr rparen)
    pp_infixly v
      = parens (sep [ppr v, pp_expr])

ppr_expr (HsCase expr matches)
  = sep [ sep [ptext SLIT("case"), nest 4 (ppr expr), ptext SLIT("of")],
	    nest 2 (pprMatches CaseAlt matches) ]

ppr_expr (HsIf e1 e2 e3)
  = sep [hsep [ptext SLIT("if"), nest 2 (ppr e1), ptext SLIT("then")],
	   nest 4 (ppr e2),
	   ptext SLIT("else"),
	   nest 4 (ppr e3)]

-- special case: let ... in let ...
ppr_expr (HsLet binds expr@(L _ (HsLet _ _)))
  = sep [hang (ptext SLIT("let")) 2 (hsep [pprBinds binds, ptext SLIT("in")]),
	 ppr_lexpr expr]

ppr_expr (HsLet binds expr)
  = sep [hang (ptext SLIT("let")) 2 (pprBinds binds),
	 hang (ptext SLIT("in"))  2 (ppr expr)]

ppr_expr (HsDo do_or_list_comp stmts _ _) = pprDo do_or_list_comp stmts

ppr_expr (ExplicitList _ exprs)
  = brackets (fsep (punctuate comma (map ppr_lexpr exprs)))

ppr_expr (ExplicitPArr _ exprs)
  = pa_brackets (fsep (punctuate comma (map ppr_lexpr exprs)))

ppr_expr (ExplicitTuple exprs boxity)
  = tupleParens boxity (sep (punctuate comma (map ppr_lexpr exprs)))

ppr_expr (RecordCon con_id rbinds)
  = pp_rbinds (ppr con_id) rbinds
ppr_expr (RecordConOut data_con con rbinds)
  = pp_rbinds (ppr con) rbinds

ppr_expr (RecordUpd aexp rbinds)
  = pp_rbinds (pprParendExpr aexp) rbinds
ppr_expr (RecordUpdOut aexp _ _ rbinds)
  = pp_rbinds (pprParendExpr aexp) rbinds

ppr_expr (ExprWithTySig expr sig)
  = hang (nest 2 (ppr_lexpr expr) <+> dcolon)
	 4 (ppr sig)
ppr_expr (ExprWithTySigOut expr sig)
  = hang (nest 2 (ppr_lexpr expr) <+> dcolon)
	 4 (ppr sig)

ppr_expr (ArithSeqIn info)
  = brackets (ppr info)
ppr_expr (ArithSeqOut expr info)
  = brackets (ppr info)

ppr_expr (PArrSeqIn info)
  = pa_brackets (ppr info)
ppr_expr (PArrSeqOut expr info)
  = pa_brackets (ppr info)

ppr_expr EWildPat = char '_'
ppr_expr (ELazyPat e) = char '~' <> pprParendExpr e
ppr_expr (EAsPat v e) = ppr v <> char '@' <> pprParendExpr e

ppr_expr (HsSCC lbl expr)
  = sep [ ptext SLIT("_scc_") <+> doubleQuotes (ftext lbl), pprParendExpr expr ]

ppr_expr (TyLam tyvars expr)
  = hang (hsep [ptext SLIT("/\\"), 
		hsep (map (pprBndr LambdaBind) tyvars), 
		ptext SLIT("->")])
	 4 (ppr_lexpr expr)

ppr_expr (TyApp expr [ty])
  = hang (ppr_lexpr expr) 4 (pprParendType ty)

ppr_expr (TyApp expr tys)
  = hang (ppr_lexpr expr)
	 4 (brackets (interpp'SP tys))

ppr_expr (DictLam dictvars expr)
  = hang (hsep [ptext SLIT("\\{-dict-}"), 
	  	hsep (map (pprBndr LambdaBind) dictvars), 
		ptext SLIT("->")])
	 4 (ppr_lexpr expr)

ppr_expr (DictApp expr [dname])
  = hang (ppr_lexpr expr) 4 (ppr dname)

ppr_expr (DictApp expr dnames)
  = hang (ppr_lexpr expr)
	 4 (brackets (interpp'SP dnames))

ppr_expr (HsType id) = ppr id

ppr_expr (HsSpliceE s)       = pprSplice s
ppr_expr (HsBracket b)       = pprHsBracket b
ppr_expr (HsBracketOut e []) = ppr e	
ppr_expr (HsBracketOut e ps) = ppr e $$ ptext SLIT("pending") <+> ppr ps

ppr_expr (HsProc pat (L _ (HsCmdTop cmd _ _ _)))
  = hsep [ptext SLIT("proc"), ppr pat, ptext SLIT("->"), ppr cmd]

ppr_expr (HsArrApp arrow arg _ HsFirstOrderApp True)
  = hsep [ppr_lexpr arrow, ptext SLIT("-<"), ppr_lexpr arg]
ppr_expr (HsArrApp arrow arg _ HsFirstOrderApp False)
  = hsep [ppr_lexpr arg, ptext SLIT(">-"), ppr_lexpr arrow]
ppr_expr (HsArrApp arrow arg _ HsHigherOrderApp True)
  = hsep [ppr_lexpr arrow, ptext SLIT("-<<"), ppr_lexpr arg]
ppr_expr (HsArrApp arrow arg _ HsHigherOrderApp False)
  = hsep [ppr_lexpr arg, ptext SLIT(">>-"), ppr_lexpr arrow]

ppr_expr (HsArrForm (L _ (HsVar v)) (Just _) [arg1, arg2])
  = sep [pprCmdArg (unLoc arg1), hsep [pprInfix v, pprCmdArg (unLoc arg2)]]
ppr_expr (HsArrForm op _ args)
  = hang (ptext SLIT("(|") <> ppr_lexpr op)
	 4 (sep (map (pprCmdArg.unLoc) args) <> ptext SLIT("|)"))

pprCmdArg :: OutputableBndr id => HsCmdTop id -> SDoc
pprCmdArg (HsCmdTop cmd@(L _ (HsArrForm _ Nothing [])) _ _ _)
  = ppr_lexpr cmd
pprCmdArg (HsCmdTop cmd _ _ _)
  = parens (ppr_lexpr cmd)

-- Put a var in backquotes if it's not an operator already
pprInfix :: Outputable name => name -> SDoc
pprInfix v | isOperator ppr_v = ppr_v
	   | otherwise        = char '`' <> ppr_v <> char '`'
	   where
	     ppr_v = ppr v

-- add parallel array brackets around a document
--
pa_brackets :: SDoc -> SDoc
pa_brackets p = ptext SLIT("[:") <> p <> ptext SLIT(":]")    
\end{code}

Parenthesize unless very simple:
\begin{code}
pprParendExpr :: OutputableBndr id => LHsExpr id -> SDoc
pprParendExpr expr
  = let
	pp_as_was = ppr_lexpr expr
	-- Using ppr_expr here avoids the call to 'deeper'
	-- Not sure if that's always right.
    in
    case unLoc expr of
      HsLit l		-> ppr l
      HsOverLit l 	-> ppr l
			
      HsVar _		-> pp_as_was
      HsIPVar _		-> pp_as_was
      ExplicitList _ _  -> pp_as_was
      ExplicitPArr _ _  -> pp_as_was
      ExplicitTuple _ _	-> pp_as_was
      HsPar _		-> pp_as_was
      HsBracket _	-> pp_as_was
      HsBracketOut _ []	-> pp_as_was
			
      _			-> parens pp_as_was
\end{code}

%************************************************************************
%*									*
\subsection{Commands (in arrow abstractions)}
%*									*
%************************************************************************

We re-use HsExpr to represent these.

\begin{code}
type HsCmd id = HsExpr id

type LHsCmd id = LHsExpr id

data HsArrAppType = HsHigherOrderApp | HsFirstOrderApp
\end{code}

The legal constructors for commands are:

  = HsArrApp ...		-- as above

  | HsArrForm ...		-- as above

  | HsApp	(HsCmd id)
		(HsExpr id)

  | HsLam	(Match  id)	-- kappa

  -- the renamer turns this one into HsArrForm
  | OpApp	(HsExpr id)	-- left operand
		(HsCmd id)	-- operator
		Fixity		-- Renamer adds fixity; bottom until then
		(HsCmd id)	-- right operand

  | HsPar	(HsCmd id)	-- parenthesised command

  | HsCase	(HsExpr id)
		[Match id]	-- bodies are HsCmd's
		SrcLoc

  | HsIf	(HsExpr id)	--  predicate
		(HsCmd id)	--  then part
		(HsCmd id)	--  else part
		SrcLoc

  | HsLet	(HsBinds id)	-- let(rec)
		(HsCmd  id)

  | HsDo	(HsStmtContext Name)	-- The parameterisation is unimportant
					-- because in this context we never use
					-- the PatGuard or ParStmt variant
		[Stmt id]	-- HsExpr's are really HsCmd's
		(ReboundNames id)
		PostTcType	-- Type of the whole expression
		SrcLoc

Top-level command, introducing a new arrow.
This may occur inside a proc (where the stack is empty) or as an
argument of a command-forming operator.

\begin{code}
type LHsCmdTop id = Located (HsCmdTop id)

data HsCmdTop id
  = HsCmdTop	(LHsCmd id)
		[PostTcType]	-- types of inputs on the command's stack
		PostTcType	-- return type of the command
		(ReboundNames id)
				-- after type checking:
				-- names used in the command's desugaring
\end{code}

%************************************************************************
%*									*
\subsection{Record binds}
%*									*
%************************************************************************

\begin{code}
type HsRecordBinds id = [(Located id, LHsExpr id)]

recBindFields :: HsRecordBinds id -> [id]
recBindFields rbinds = [unLoc field | (field,_) <- rbinds]

pp_rbinds :: OutputableBndr id => SDoc -> HsRecordBinds id -> SDoc
pp_rbinds thing rbinds
  = hang thing 
	 4 (braces (sep (punctuate comma (map (pp_rbind) rbinds))))
  where
    pp_rbind (v, e) = hsep [pprBndr LetBind (unLoc v), char '=', ppr e]
\end{code}



%************************************************************************
%*									*
\subsection{@Match@, @GRHSs@, and @GRHS@ datatypes}
%*									*
%************************************************************************

@Match@es are sets of pattern bindings and right hand sides for
functions, patterns or case branches. For example, if a function @g@
is defined as:
\begin{verbatim}
g (x,y) = y
g ((x:ys),y) = y+1,
\end{verbatim}
then \tr{g} has two @Match@es: @(x,y) = y@ and @((x:ys),y) = y+1@.

It is always the case that each element of an @[Match]@ list has the
same number of @pats@s inside it.  This corresponds to saying that
a function defined by pattern matching must have the same number of
patterns in each equation.

\begin{code}
type LMatch id = Located (Match id)

data Match id
  = Match
	[LPat id]		-- The patterns
	(Maybe (LHsType id))	-- A type signature for the result of the match
				--	Nothing after typechecking

	(GRHSs id)

-- GRHSs are used both for pattern bindings and for Matches
data GRHSs id	
  = GRHSs [LGRHS id]		-- Guarded RHSs
	  [HsBindGroup id]	-- The where clause
	  PostTcType		-- Type of RHS (after type checking)

type LGRHS id = Located (GRHS id)

data GRHS id
  = GRHS  [LStmt id]		-- The RHS is the final ResultStmt
\end{code}

We know the list must have at least one @Match@ in it.

\begin{code}
pprMatches :: (OutputableBndr id) => HsMatchContext id -> [LMatch id] -> SDoc
pprMatches ctxt matches = vcat (map (pprMatch ctxt) (map unLoc matches))

-- Exported to HsBinds, which can't see the defn of HsMatchContext
pprFunBind :: (OutputableBndr id) => id -> [LMatch id] -> SDoc
pprFunBind fun matches = pprMatches (FunRhs fun) matches

-- Exported to HsBinds, which can't see the defn of HsMatchContext
pprPatBind :: (OutputableBndr id)
	   => LPat id -> GRHSs id -> SDoc
pprPatBind pat grhss = sep [ppr pat, nest 4 (pprGRHSs PatBindRhs grhss)]


pprMatch :: OutputableBndr id => HsMatchContext id -> Match id -> SDoc
pprMatch ctxt (Match pats maybe_ty grhss)
  = pp_name ctxt <+> sep [sep (map ppr pats), 
		     ppr_maybe_ty,
		     nest 2 (pprGRHSs ctxt grhss)]
  where
    pp_name (FunRhs fun) = ppr fun	-- Not pprBndr; the AbsBinds will
					-- have printed the signature
    pp_name LambdaExpr   = char '\\'
    pp_name other	 = empty

    ppr_maybe_ty = case maybe_ty of
			Just ty -> dcolon <+> ppr ty
			Nothing -> empty


pprGRHSs :: OutputableBndr id => HsMatchContext id -> GRHSs id -> SDoc
pprGRHSs ctxt (GRHSs grhss binds ty)
  = vcat (map (pprGRHS ctxt . unLoc) grhss)
    $$
    (if null binds then empty
     else text "where" $$ nest 4 (pprBinds binds))

pprGRHS :: OutputableBndr id => HsMatchContext id -> GRHS id -> SDoc

pprGRHS ctxt (GRHS [L _ (ResultStmt expr)])
 =  pp_rhs ctxt expr

pprGRHS ctxt (GRHS guarded)
 = sep [char '|' <+> interpp'SP guards, pp_rhs ctxt expr]
 where
    ResultStmt expr = unLoc (last guarded)
	-- Last stmt should be a ResultStmt for guards
    guards	    = init guarded

pp_rhs ctxt rhs = matchSeparator ctxt <+> pprDeeper (ppr rhs)
\end{code}

%************************************************************************
%*									*
\subsection{Do stmts and list comprehensions}
%*									*
%************************************************************************

\begin{code}
type LStmt id = Located (Stmt id)

data Stmt id
  = BindStmt	(LPat id) (LHsExpr id)
  | LetStmt	[HsBindGroup id]
  | ResultStmt	(LHsExpr id)			-- See notes that follow
  | ExprStmt	(LHsExpr id)	PostTcType	-- See notes that follow
	-- The type is the *element type* of the expression

	-- ParStmts only occur in a list comprehension
  | ParStmt	[([LStmt id], [id])]	-- After remaing, the ids are the binders
					-- bound by the stmts and used subsequently

	-- Recursive statement
  | RecStmt  [LStmt id] 
		--- The next two fields are only valid after renaming
	     [id] 	-- The ids are a subset of the variables bound by the stmts
	     	 	-- that are used in stmts that follow the RecStmt

	     [id]	-- Ditto, but these variables are the "recursive" ones, that 
			-- are used before they are bound in the stmts of the RecStmt
			-- From a type-checking point of view, these ones have to be monomorphic

		--- This field is only valid after typechecking
	     [LHsExpr id]	-- These expressions correspond
				-- 1-to-1 with the "recursive" [id], and are the expresions that 
				-- should be returned by the recursion.  They may not quite be the
				-- Ids themselves, because the Id may be *polymorphic*, but
				-- the returned thing has to be *monomorphic*.
\end{code}

ExprStmts and ResultStmts are a bit tricky, because what they mean
depends on the context.  Consider the following contexts:

	A do expression of type (m res_ty)
	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	* ExprStmt E any_ty:   do { ....; E; ... }
		E :: m any_ty
	  Translation: E >> ...
	
	* ResultStmt E:   do { ....; E }
		E :: m res_ty
	  Translation: E
	
	A list comprehensions of type [elt_ty]
	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	* ExprStmt E Bool:   [ .. | .... E ]
			[ .. | ..., E, ... ]
			[ .. | .... | ..., E | ... ]
		E :: Bool
	  Translation: if E then fail else ...

	* ResultStmt E:   [ E | ... ]
		E :: elt_ty
	  Translation: return E
	
	A guard list, guarding a RHS of type rhs_ty
	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	* ExprStmt E Bool:   f x | ..., E, ... = ...rhs...
		E :: Bool
	  Translation: if E then fail else ...
	
	* ResultStmt E:   f x | ...guards... = E
		E :: rhs_ty
	  Translation: E

Array comprehensions are handled like list comprehensions -=chak

\begin{code}
instance OutputableBndr id => Outputable (Stmt id) where
    ppr stmt = pprStmt stmt

pprStmt (BindStmt pat expr) 	= hsep [ppr pat, ptext SLIT("<-"), ppr expr]
pprStmt (LetStmt binds)       	= hsep [ptext SLIT("let"), pprBinds binds]
pprStmt (ExprStmt expr _)   	= ppr expr
pprStmt (ResultStmt expr)   	= ppr expr
pprStmt (ParStmt stmtss)        = hsep (map (\stmts -> ptext SLIT("| ") <> ppr stmts) stmtss)
pprStmt (RecStmt segment _ _ _) = ptext SLIT("rec") <+> braces (vcat (map ppr segment))

pprDo :: OutputableBndr id => HsStmtContext any -> [LStmt id] -> SDoc
pprDo DoExpr stmts   = hang (ptext SLIT("do")) 2 (vcat (map ppr stmts))
pprDo MDoExpr stmts  = hang (ptext SLIT("mdo")) 3 (vcat (map ppr stmts))
pprDo ListComp stmts = pprComp brackets   stmts
pprDo PArrComp stmts = pprComp pa_brackets stmts

pprComp :: OutputableBndr id => (SDoc -> SDoc) -> [LStmt id] -> SDoc
pprComp brack stmts
  = brack $
	hang (ppr expr <+> char '|')
	     4 (interpp'SP quals)
  where
      ResultStmt expr = unLoc (last stmts)  -- Last stmt should
      quals	      = init stmts  -- be an ResultStmt
\end{code}

%************************************************************************
%*									*
		Template Haskell quotation brackets
%*									*
%************************************************************************

\begin{code}
data HsSplice id  = HsSplice 	-- $z  or $(f 4)
			id 		-- The id is just a unique name to 
			(LHsExpr id) 	-- identify this splice point
					
instance OutputableBndr id => Outputable (HsSplice id) where
  ppr = pprSplice

pprSplice :: OutputableBndr id => HsSplice id -> SDoc
pprSplice (HsSplice n e) = char '$' <> brackets (ppr n) <> pprParendExpr e


data HsBracket id = ExpBr (LHsExpr id)		-- [|  expr  |]
		  | PatBr (LPat id)		-- [p| pat   |]
		  | DecBr (HsGroup id)		-- [d| decls |]
		  | TypBr (LHsType id)		-- [t| type  |]
		  | VarBr id			-- 'x, ''T

instance OutputableBndr id => Outputable (HsBracket id) where
  ppr = pprHsBracket


pprHsBracket (ExpBr e) = thBrackets empty (ppr e)
pprHsBracket (PatBr p) = thBrackets (char 'p') (ppr p)
pprHsBracket (DecBr d) = thBrackets (char 'd') (ppr d)
pprHsBracket (TypBr t) = thBrackets (char 't') (ppr t)
pprHsBracket (VarBr n) = char '\'' <> ppr n
	-- Infelicity: can't show ' vs '', because
	-- we can't ask n what its OccName is, because the 
	-- pretty-printer for HsExpr doesn't ask for NamedThings
	-- But the pretty-printer for names will show the OccName class

thBrackets pp_kind pp_body = char '[' <> pp_kind <> char '|' <+> 
			     pp_body <+> ptext SLIT("|]")
\end{code}

%************************************************************************
%*									*
\subsection{Enumerations and list comprehensions}
%*									*
%************************************************************************

\begin{code}
data ArithSeqInfo id
  = From	    (LHsExpr id)
  | FromThen 	    (LHsExpr id)
		    (LHsExpr id)
  | FromTo	    (LHsExpr id)
		    (LHsExpr id)
  | FromThenTo	    (LHsExpr id)
		    (LHsExpr id)
		    (LHsExpr id)
\end{code}

\begin{code}
instance OutputableBndr id => Outputable (ArithSeqInfo id) where
    ppr (From e1)		= hcat [ppr e1, pp_dotdot]
    ppr (FromThen e1 e2)	= hcat [ppr e1, comma, space, ppr e2, pp_dotdot]
    ppr (FromTo e1 e3)	= hcat [ppr e1, pp_dotdot, ppr e3]
    ppr (FromThenTo e1 e2 e3)
      = hcat [ppr e1, comma, space, ppr e2, pp_dotdot, ppr e3]

pp_dotdot = ptext SLIT(" .. ")
\end{code}


%************************************************************************
%*									*
\subsection{HsMatchCtxt}
%*									*
%************************************************************************

\begin{code}
data HsMatchContext id	-- Context of a Match
  = FunRhs id			-- Function binding for f
  | CaseAlt			-- Guard on a case alternative
  | LambdaExpr			-- Pattern of a lambda
  | ProcExpr			-- Pattern of a proc
  | PatBindRhs			-- Pattern binding
  | RecUpd			-- Record update [used only in DsExpr to tell matchWrapper
				-- 	what sort of runtime error message to generate]
  | StmtCtxt (HsStmtContext id)	-- Pattern of a do-stmt or list comprehension
  deriving ()

data HsStmtContext id
  = ListComp 
  | DoExpr 
  | MDoExpr				-- Recursive do-expression
  | PArrComp				-- Parallel array comprehension
  | PatGuard (HsMatchContext id)	-- Pattern guard for specified thing
  | ParStmtCtxt (HsStmtContext id)	-- A branch of a parallel stmt 
\end{code}

\begin{code}
isDoExpr :: HsStmtContext id -> Bool
isDoExpr DoExpr  = True
isDoExpr MDoExpr = True
isDoExpr other   = False
\end{code}

\begin{code}
matchSeparator (FunRhs _)   = ptext SLIT("=")
matchSeparator CaseAlt      = ptext SLIT("->") 
matchSeparator LambdaExpr   = ptext SLIT("->") 
matchSeparator ProcExpr     = ptext SLIT("->") 
matchSeparator PatBindRhs   = ptext SLIT("=") 
matchSeparator (StmtCtxt _) = ptext SLIT("<-")  
matchSeparator RecUpd       = panic "unused"
\end{code}

\begin{code}
pprMatchContext (FunRhs fun) 	  = ptext SLIT("the definition of") <+> quotes (ppr fun)
pprMatchContext CaseAlt	     	  = ptext SLIT("a case alternative")
pprMatchContext RecUpd	     	  = ptext SLIT("a record-update construct")
pprMatchContext PatBindRhs   	  = ptext SLIT("a pattern binding")
pprMatchContext LambdaExpr   	  = ptext SLIT("a lambda abstraction")
pprMatchContext ProcExpr   	  = ptext SLIT("an arrow abstraction")
pprMatchContext (StmtCtxt ctxt)   = ptext SLIT("a pattern binding in") $$ pprStmtContext ctxt

pprMatchRhsContext (FunRhs fun) = ptext SLIT("a right-hand side of function") <+> quotes (ppr fun)
pprMatchRhsContext CaseAlt	= ptext SLIT("the body of a case alternative")
pprMatchRhsContext PatBindRhs	= ptext SLIT("the right-hand side of a pattern binding")
pprMatchRhsContext LambdaExpr	= ptext SLIT("the body of a lambda")
pprMatchRhsContext ProcExpr	= ptext SLIT("the body of a proc")
pprMatchRhsContext RecUpd	= panic "pprMatchRhsContext"

pprStmtContext (ParStmtCtxt c) = sep [ptext SLIT("a parallel branch of"), pprStmtContext c]
pprStmtContext (PatGuard ctxt) = ptext SLIT("a pattern guard for") $$ pprMatchContext ctxt
pprStmtContext DoExpr          = ptext SLIT("a 'do' expression")
pprStmtContext MDoExpr         = ptext SLIT("an 'mdo' expression")
pprStmtContext ListComp        = ptext SLIT("a list comprehension")
pprStmtContext PArrComp        = ptext SLIT("an array comprehension")

-- Used for the result statement of comprehension
-- e.g. the 'e' in	[ e | ... ]
--	or the 'r' in   f x = r
pprStmtResultContext (PatGuard ctxt) = pprMatchRhsContext ctxt
pprStmtResultContext other	     = ptext SLIT("the result of") <+> pprStmtContext other


-- Used to generate the string for a *runtime* error message
matchContextErrString (FunRhs fun)    	      	 = "function " ++ showSDoc (ppr fun)
matchContextErrString CaseAlt	      	      	 = "case"
matchContextErrString PatBindRhs      	      	 = "pattern binding"
matchContextErrString RecUpd	      	      	 = "record update"
matchContextErrString LambdaExpr      	      	 = "lambda"
matchContextErrString ProcExpr      	      	 = "proc"
matchContextErrString (StmtCtxt (ParStmtCtxt c)) = matchContextErrString (StmtCtxt c)
matchContextErrString (StmtCtxt (PatGuard _)) 	 = "pattern guard"
matchContextErrString (StmtCtxt DoExpr)       	 = "'do' expression"
matchContextErrString (StmtCtxt MDoExpr)      	 = "'mdo' expression"
matchContextErrString (StmtCtxt ListComp)     	 = "list comprehension"
matchContextErrString (StmtCtxt PArrComp)     	 = "array comprehension"
\end{code}
