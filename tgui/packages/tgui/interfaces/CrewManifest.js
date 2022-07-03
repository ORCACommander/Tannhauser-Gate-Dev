import { classes } from 'common/react';
import { useBackend } from '../backend';
import { Icon, Section, Table, Tooltip } from '../components';
import { Window } from '../layouts';

const commandJobs = [
  'Head of Personnel',
  'Head of Security',
  'Chief Engineer',
  'Research Director',
  'Chief Medical Officer',
  'Quartermaster', // SKYRAT EDIT
  'Nanotrasen Consultant', // SKYRAT EDIT
];

// SKYRAT EDIT CHANGE BEGIN - ALTERNATIVE_JOB_TITLES
// Any instance of crewMember.trim was originally crewMember.rank
export const CrewManifest = (props, context) => {
  const {
    data: { manifest, positions },
  } = useBackend(context);

  return (
    <Window title="Crew Manifest" width={350} height={500}>
      <Window.Content scrollable>
        {Object.entries(manifest).map(([dept, crew]) => (
          <Section
            className={'CrewManifest--' + dept}
            key={dept}
            title={
              dept +
              (dept !== 'Misc'
                ? ` (${positions[dept].open} positions open)`
                : '')
            }>
            <Table>
              {Object.entries(crew).map(([crewIndex, crewMember]) => (
                <Table.Row key={crewIndex}>
                  <Table.Cell className={'CrewManifest__Cell'}>
                    {crewMember.name}
                  </Table.Cell>
                  <Table.Cell
                    className={classes([
                      'CrewManifest__Cell',
                      'CrewManifest__Icons',
                    ])}
                    collapsing>
                    {positions[dept].exceptions.includes(crewMember.trim) && (
                      <Tooltip content="No position limit" position="bottom">
                        <Icon className="CrewManifest__Icon" name="infinity" />
                      </Tooltip>
                    )}
                    {crewMember.trim === 'Captain' && (
                      <Tooltip content="Captain" position="bottom">
                        <Icon
                          className={classes([
                            'CrewManifest__Icon',
                            'CrewManifest__Icon--Command',
                          ])}
                          name="star"
                        />
                      </Tooltip>
                    )}
                    {commandJobs.includes(crewMember.trim) && (
                      <Tooltip content="Member of command" position="bottom">
                        <Icon
                          className={classes([
                            'CrewManifest__Icon',
                            'CrewManifest__Icon--Command',
                            'CrewManifest__Icon--Chevron',
                          ])}
                          name="chevron-up"
                        />
                      </Tooltip>
                    )}
                  </Table.Cell>
                  <Table.Cell
                    className={classes([
                      'CrewManifest__Cell',
                      'CrewManifest__Cell--Rank',
                    ])}
                    collapsing>
                    {crewMember.rank}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        ))}
      </Window.Content>
    </Window>
  );
};
// SKYRAT EDIT CHANGE END - ALTERNATIVE_JOB_TITLES
