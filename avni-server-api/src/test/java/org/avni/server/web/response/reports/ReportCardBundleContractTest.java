package org.avni.server.web.response.reports;

import org.junit.Test;
import java.util.Arrays;
import static org.junit.Assert.*;

public class ReportCardBundleContractTest {
    @Test
    public void testGettersAndSetters() {
        ReportCardBundleContract contract = new ReportCardBundleContract();
        
        contract.setStandardReportCardType("TYPE1");
        contract.setStandardReportCardInputSubjectTypes(Arrays.asList("Subject1", "Subject2"));
        contract.setStandardReportCardInputPrograms(Arrays.asList("Program1"));
        contract.setStandardReportCardInputEncounterTypes(Arrays.asList("Encounter1", "Encounter2"));
        contract.setStandardReportCardInputRecentDuration("30d");
        
        assertEquals("TYPE1", contract.getStandardReportCardType());
        assertEquals(2, contract.getStandardReportCardInputSubjectTypes().size());
        assertEquals(1, contract.getStandardReportCardInputPrograms().size());
        assertEquals(2, contract.getStandardReportCardInputEncounterTypes().size());
        assertEquals("30d", contract.getStandardReportCardInputRecentDuration());
    }
}
