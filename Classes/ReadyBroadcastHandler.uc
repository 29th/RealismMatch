/*
	REALISM MATCH Broadcast Handler v1.0
	by Captain Wilson
	I learnt how to do this from Crube's RO Team Ready Mutator
*/
class ReadyBroadcastHandler extends BroadcastHandler;

var MutRealismMatch MatchMutator;

function bool AcceptBroadcastText( PlayerController Receiver, PlayerReplicationInfo SenderPRI, out string Msg, optional name Type )
{
	if( Msg ~= "/ready" )
	{
		log( "/ready" );
		MatchMutator.TeamReady( SenderPRI, true );
		return false;
	}

	else if( Msg ~= "/notready" )
	{
		log( "/notready" );
		MatchMutator.TeamReady( SenderPRI, false );
		return false;
	}

	return super.AcceptBroadcastText(Receiver, SenderPRI, Msg, Type);
}

defaultproperties
{
}
