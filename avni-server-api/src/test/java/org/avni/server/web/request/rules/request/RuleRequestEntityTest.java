package org.avni.server.web.request.rules.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class RuleRequestEntityTest {
    @Test
    public void testGettersAndSetters() {
        RuleRequestEntity entity = new RuleRequestEntity();
        
        entity.setWorkFlowType("workflow");
        assertEquals("workflow", entity.getWorkFlowType());
        
        entity.setDecisionCode("decision");
        assertEquals("decision", entity.getDecisionCode());
        
        entity.setVisitScheduleCode("schedule");
        assertEquals("schedule", entity.getVisitScheduleCode());
        
        entity.setChecklistCode("checklist");
        assertEquals("checklist", entity.getChecklistCode());
        
        entity.setProgramSummaryCode("program");
        assertEquals("program", entity.getProgramSummaryCode());
        
        entity.setSubjectSummaryCode("subject");
        assertEquals("subject", entity.getSubjectSummaryCode());
    }
}
